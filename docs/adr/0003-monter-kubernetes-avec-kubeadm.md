# 0003. Monter Kubernetes avec kubeadm

- Statut : accepté le 2026-11-21, après mesure (proposé le 2026-11-20)
- Date : 2026-11-20

## Contexte

La plateforme héberge rtgre, sa reconstruction horaire et la supervision sur Kubernetes. Les ressources disponibles sont celles de l'[ADR 0002](0002-heberger-sur-oracle-cloud-always-free.md) : 2 OCPU et 12 Go en ARM, sur une ou deux instances.

Le cluster doit être reconstructible de zéro, sans action manuelle, à partir du dépôt.

## Options envisagées

### kubeadm

L'outil de référence pour monter un cluster Kubernetes standard. Chaque composant est visible : runtime de conteneurs, plan de contrôle, etcd, CNI. Il faut tout installer et tout configurer soi-même, et kubeadm attend 2 CPU pour un nœud du plan de contrôle.

### k3s

Une distribution légère en un seul binaire, avec des choix par défaut intégrés (Flannel, Traefik, SQLite ou etcd embarqué). Très économe et rapide à installer, mais elle masque une grande partie de ce qu'il faut savoir configurer.

### Service managé Oracle (OKE)

Le plan de contrôle est géré par Oracle. Les nœuds restent ceux de l'offre gratuite, mais une partie du fonctionnement du cluster échappe au dépôt.

## Décision

kubeadm, piloté par des rôles Ansible. C'est la façon la plus directe de maîtriser chaque composant du cluster, et elle correspond au périmètre de la certification CKA.

Topologie retenue : deux instances A1 de 1 OCPU et 6 Go, un nœud de plan de contrôle et un nœud de travail. La vérification `NumCPU` de kubeadm est ignorée explicitement sur le plan de contrôle, et cet écart est documenté dans le rôle Ansible.


## Mesures

Relevées le 2026-11-21 avec `scripts/measure-node.sh` (un échantillon toutes les 5 s), sur Kubernetes 1.36.6 avec Cilium.

| | cp-1 au repos (5 min) | cp-1 en charge (4 min) | wk-1 au repos (5 min) | wk-1 en charge (4 min) |
| --- | --- | --- | --- | --- |
| Processeur occupé, moyenne | 9,5 % | 14,3 % | 2,0 % | 16,3 % |
| Processeur occupé, maximum | 39 % | 58 % | 3 % | 100 % |
| Temps volé par l'hyperviseur, maximum | 1 % | 7 % | 0 % | 7 % |
| Mémoire disponible | 4 585 Mo | 4 558 Mo | 5 189 Mo | 5 133 Mo |

La charge : création de 10 pods nginx, passage à 20, redémarrage progressif des 20, dix `kubectl get pods -A`, puis suppression de l'espace de noms.

| Opération | Durée |
| --- | --- |
| 10 pods prêts | 10,8 s |
| Passage de 10 à 20 pods | 8,2 s |
| Redémarrage progressif des 20 pods | 18,1 s |
| `kubectl get pods -A` | 0,1 s par requête |

Au repos, le plan de contrôle consomme 64 millicœurs et 620 Mo pour ses conteneurs : kube-apiserver (282 Mo), l'agent Cilium (150 Mo), etcd (41 Mo).

**Le plan de contrôle à 1 OCPU ne sature pas**, ni au repos ni pendant les déploiements, et l'API reste réactive. La limite est sur le nœud de travail, qui atteint 100 % de processeur pendant le démarrage simultané de 20 conteneurs.

## Conséquences

- Tout le montage du cluster est du code Ansible, testé avant d'être appliqué.
- Deux nœuds permettent de vrais scénarios d'exploitation : ajout d'un nœud, vidage avant maintenance, perte d'un nœud.
- Le plan de contrôle n'a qu'un cœur, et la mesure montre qu'il suffit : la topologie à deux nœuds est conservée.
- La capacité pour les applications est celle de `wk-1` : 1 OCPU et environ 5 Go. Le plan de contrôle reste peu occupé (moins de 15 % en moyenne) : y autoriser des charges légères de la plateforme pourra faire l'objet d'un ADR, si `wk-1` devient insuffisant.
- La mesure se refait avec `scripts/measure-node.sh` après chaque ajout important (ArgoCD, supervision), pour suivre ce qu'il reste.
- Les mises à jour de Kubernetes sont manuelles et suivent la procédure `kubeadm upgrade`, décrite dans un runbook.
