# 0011. Stocker sur des volumes locaux statiques

- Statut : accepté
- Date : 2026-11-21

## Contexte

Un cluster kubeadm n'a aucun stockage persistant : rien ne répond à un PersistentVolumeClaim. Le site de rtgre en a besoin : le générateur écrit le site, un serveur web le lit, et le dernier site publié doit survivre au redémarrage d'un pod, y compris quand ADE ne répond plus. La métrologie de la phase 5 en aura besoin aussi.

Les contraintes :

- un seul nœud de travail, de 6 Go de mémoire ([ADR 0003](0003-monter-kubernetes-avec-kubeadm.md)) ;
- aucune vulnérabilité HIGH ou CRITICAL connue dans ce qui est déployé ;
- des espaces de noms au niveau Pod Security le plus strict possible ;
- des données qui se reconstruisent : le site est régénéré chaque heure.

## Options envisagées

### local-path-provisioner

Crée un dossier du nœud à chaque demande : c'est le choix habituel d'un cluster de ce type, et celui que prévoyait le plan. Mais Trivy relève 17 vulnérabilités HIGH dans son image (v0.0.37, la dernière, publiée en août 2026). De plus, il crée et supprime les dossiers avec des pods auxiliaires qui tournent en root avec un volume `hostPath`, ce qui impose le niveau Pod Security `privileged` à son espace de noms.

### Volumes bloc d'Oracle, par le pilote CSI

Les volumes suivraient un pod d'un nœud à l'autre et survivraient à la perte du nœud. Mais un volume bloc fait au moins 50 Go, sur les 200 Go gratuits que les deux disques de démarrage entament déjà. Le pilote demande des droits sur l'API d'Oracle depuis le cluster, et ajoute plusieurs pods.

### Volumes locaux statiques

Fonction native de Kubernetes : une classe de stockage sans approvisionneur, et un PersistentVolume de type `local` par volume, attaché à un nœud. Aucun composant à installer, donc ni image ni mémoire en plus. Chaque volume doit être déclaré à l'avance, et son dossier créé sur le nœud.

## Décision

Des volumes locaux statiques. Les volumes sont peu nombreux et connus d'avance : les déclarer un par un coûte moins qu'un composant vulnérable et privilégié.

- **Une seule déclaration** : `kubernetes/storage/values.yaml`. Argo CD en tire les PersistentVolume, et l'inventaire Ansible les dossiers que le rôle `local_volumes` crée sur le nœud qui porte chaque volume.
- **Un volume par demande** : chaque PersistentVolume est réservé (`claimRef`) à une demande précise.
- **Droits par `fsGroup`** : le dossier est créé fermé (`root:root`, `0770`). Au montage, kubelet le donne au groupe du pod. Des pods non-root d'utilisateurs différents partagent ainsi un volume par leur groupe, sans droit pour les autres.
- **Conservation** (`Retain`) : supprimer une demande ne supprime pas les données.

## Conséquences

- Aucun composant de stockage ne tourne dans le cluster, et aucun espace de noms n'a besoin du niveau `privileged`.
- Ajouter un volume demande une entrée dans les valeurs, puis un passage du playbook avant la synchronisation d'Argo CD.
- Un volume dont la demande a été supprimée reste réservé à l'ancienne : il faut le libérer à la main ([README de `kubernetes/storage`](../../kubernetes/storage/README.md)).
- Les données sont liées au nœud : s'il est remplacé, elles sont perdues. C'est acceptable pour un site régénéré chaque heure. Ce ne le serait pas pour des données irremplaçables, qui demanderaient une sauvegarde hors du nœud (phase 7).
- Un volume local n'applique pas de quota : la taille déclarée est indicative. La place sur le disque du nœud sera surveillée en phase 5.
- Si les volumes se multiplient ou si un second nœud de travail arrive, cette décision sera à revoir.
