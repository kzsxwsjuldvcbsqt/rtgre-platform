# 0009. Réseau des pods avec Cilium, sur Kubernetes 1.36

- Statut : accepté
- Date : 2026-11-21

## Contexte

Un cluster kubeadm n'a pas de réseau de pods tant qu'aucun CNI n'est installé. Le choix doit tenir compte :

- des ressources : deux nœuds de 1 OCPU et 6 Go ([ADR 0003](0003-monter-kubernetes-avec-kubeadm.md)) ;
- de l'architecture ARM64 et du noyau des nœuds (7.0) ;
- du besoin de **politiques réseau** (NetworkPolicy), pour isoler les applications dans les phases suivantes ;
- de la matrice de compatibilité entre le CNI et la version de Kubernetes.

## Options envisagées

### Flannel

Le plus léger, mais il n'applique pas les NetworkPolicy.

### Calico

Applique les NetworkPolicy et sait fonctionner en eBPF. Son installation recommandée passe par un opérateur qui ajoute ses propres composants.

### Cilium

Fondé sur eBPF. Il applique les NetworkPolicy, y compris au niveau applicatif, et apporte Hubble pour observer les flux. Il supporte AArch64 et demande un noyau 5.10 ou plus. La [documentation de Cilium 1.20](https://docs.cilium.io/en/v1.20/network/kubernetes/compatibility/) ne garantit que Kubernetes **1.33 à 1.36**, alors que la dernière version de Kubernetes est la 1.37.

## Décision

Cilium 1.20, et **Kubernetes 1.36.6** plutôt que 1.37 : une combinaison testée par l'éditeur vaut mieux que la dernière version de chaque composant.

- IPAM `kubernetes` : Cilium utilise les plages attribuées aux nœuds par kubeadm (`10.244.0.0/16`). Sa plage par défaut, `10.0.0.0/8`, chevaucherait le réseau virtuel `10.20.0.0/16`.
- kube-proxy est conservé (`kubeProxyReplacement: false`) : le cluster reste standard, conforme au périmètre de la CKA. Le remplacement de kube-proxy par eBPF pourra faire l'objet d'un ADR plus tard.
- Tunnel VXLAN entre les nœuds.
- Le chart est rendu par `helm template` sur le poste de contrôle et appliqué par `kubectl` sur le plan de contrôle : aucun outil supplémentaire sur les nœuds.
- Les certificats (CA de Cilium, TLS de Hubble) sont générés dans le cluster par un Job, puis renouvelés par un CronJob. Avec la méthode par défaut, chaque rendu du chart générait une nouvelle CA.

## Conséquences

- Le rôle `kubernetes_node` installe 1.36.6 et sait rétrograder des paquets déjà installés.
- Passer à Kubernetes 1.37 attendra une version de Cilium qui le garantit. Renovate (#33) devra regrouper ces deux montées de version.
- Les NetworkPolicy sont disponibles pour les phases 4 et 6.
- Cilium consomme une partie des ressources des nœuds. La mesure de #21 dira ce qu'il reste pour les applications.
