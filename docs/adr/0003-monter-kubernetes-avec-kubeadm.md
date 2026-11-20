# 0003. Monter Kubernetes avec kubeadm

- Statut : proposé
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

Topologie proposée : deux instances A1 de 1 OCPU et 6 Go, un nœud de plan de contrôle et un nœud de travail. La vérification `NumCPU` de kubeadm est ignorée explicitement sur le plan de contrôle, et cet écart est documenté dans le rôle Ansible.

Le statut passera à « accepté » une fois les deux nœuds créés et la consommation réelle mesurée.

## Conséquences

- Tout le montage du cluster est du code Ansible, testé avant d'être appliqué.
- Deux nœuds permettent de vrais scénarios d'exploitation : ajout d'un nœud, vidage avant maintenance, perte d'un nœud.
- Le plan de contrôle n'a qu'un cœur. Si la mesure montre qu'il sature, on revient à une seule instance de 2 OCPU, plan de contrôle et nœud de travail confondus, dans un nouvel ADR.
- Les mises à jour de Kubernetes sont manuelles et suivent la procédure `kubeadm upgrade`, décrite dans un runbook.
