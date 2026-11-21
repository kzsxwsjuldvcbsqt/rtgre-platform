# 0010. Déployer en GitOps avec Argo CD

- Statut : accepté
- Date : 2026-11-21

## Contexte

Une fois le cluster monté par Ansible, ce qui tourne dedans doit rester décrit dans le dépôt et s'y conformer sans `kubectl apply` à la main. Le choix de l'outil tient compte :

- des ressources : un seul nœud de travail, de 1 OCPU et 6 Go ([ADR 0003](0003-monter-kubernetes-avec-kubeadm.md)) ;
- de l'absence d'entrée depuis Internet : aucun webhook GitHub ne peut atteindre le cluster, et l'interface d'administration ne doit pas être exposée ;
- du dépôt, destiné à devenir privé : l'outil doit s'y authentifier avec le moins de droits possible ;
- de l'objectif du projet : montrer et expliquer une chaîne GitOps complète.

## Options envisagées

### Flux

Quatre contrôleurs, sans interface ni base de données : c'est l'option la plus légère. L'état se lit avec `kubectl` ou avec la CLI `flux`. Il s'amorce avec `flux bootstrap`, qui écrit ses manifestes dans le dépôt.

### Argo CD

Plus lourd : un contrôleur, un serveur de dépôts, un serveur d'API avec son interface, et Redis. Il apporte une interface qui montre l'écart entre le dépôt et le cluster, objet par objet, et le modèle « app-of-apps », où une application racine déclare toutes les autres. Dex (SSO), les notifications et ApplicationSet sont des composants à part, que l'on peut ne pas installer.

### Rester sur Ansible

Le rôle `cilium` rend déjà un chart et l'applique. L'étendre à toutes les applications garderait un seul outil, mais rien ne corrigerait une dérive entre deux passages du playbook, et chaque déploiement demanderait une session sur le Bastion.

## Décision

Argo CD, en installation minimale : pas de Dex, pas de notifications, pas d'ApplicationSet, Redis sans haute disponibilité. Son interface justifie son poids sur un projet qui doit se montrer, et la mesure confirme que ce poids tient sur le nœud.

- **Mesure** (`scripts/measure-node.sh wk-1 120`, au repos, avant puis après) : la mémoire utilisée du nœud passe de 761 à 1 021 Mo sur 5 901, soit 260 Mo de plus, dont 180 Mo pour les quatre conteneurs d'Argo CD. Le processeur occupé passe de 2,2 % à 3,4 % en moyenne.
- **Version** : chart `argo-cd` 10.18.2, soit Argo CD 3.6.2, [testé](https://argo-cd.readthedocs.io/en/stable/operator-manual/tested-kubernetes-versions/) avec Kubernetes 1.34 à 1.37. Le cluster est en 1.36 ([ADR 0009](0009-reseau-des-pods-avec-cilium.md)).
- **Deux charts dans `kubernetes/`** : `argocd` installe le chart officiel avec les valeurs du dépôt ; `apps` est l'application racine, qui déclare le projet `platform`, les applications, et elle-même. Le dépôt suivi n'est écrit qu'à un endroit, les valeurs de `apps`.
- **Amorçage par Ansible, puis autonomie** : le rôle `argocd` installe le chart et déclare l'application racine une seule fois. Ensuite Argo CD se met à jour lui-même depuis le dépôt, comme n'importe quelle autre application.
- **Accès au dépôt par une clé de déploiement** en lecture seule, propre à ce dépôt. Sa partie privée n'existe que dans un Secret du cluster : le rôle la génère, l'enregistre sur GitHub et la dépose, sans qu'elle passe par Git.
- **Pas de webhook** : Argo CD interroge le dépôt, toutes les deux à trois minutes.
- **Interface non exposée** : le service reste en `ClusterIP`, sans Ingress. Elle s'ouvre par une redirection de port SSH à travers le Bastion ([runbook](../runbooks/acceder-a-argocd.md)).
- **Moindre privilège dans Argo CD** : le projet par défaut, qui autorise tout, est vidé. Le projet `platform` n'accepte que ce dépôt comme source. L'espace de noms `argocd` applique le niveau Pod Security `restricted`, et des NetworkPolicy refusent par défaut toute entrée vers ses pods.

## Conséquences

- Déployer une application revient à ajouter un chart sous `kubernetes/` et une entrée dans les valeurs de `apps`. Une modification manuelle du cluster est annulée par Argo CD.
- Cilium reste installé par Ansible : sans réseau de pods, Argo CD ne peut pas démarrer.
- Le plan de contrôle accepte une redirection de port SSH, vers un seul port de sa boucle locale. Les nœuds de travail n'en acceptent toujours aucune.
- Le compte `admin` d'Argo CD est le seul compte. Son mot de passe initial doit être changé à la première connexion ([runbook](../runbooks/acceder-a-argocd.md)). Un SSO n'aurait de sens qu'avec plusieurs utilisateurs.
- Une montée mineure du chart peut changer de version d'Argo CD : Renovate la soumet à une approbation, le temps de vérifier la matrice de versions de Kubernetes.
- La mesure a été prise avec une seule application. Elle sera refaite quand rtgre, cert-manager et la passerelle seront déployés.
- Les NetworkPolicy du chart ne filtrent que les entrées. Le filtrage des sorties est à traiter avec la sécurité du cluster (phase 6).
