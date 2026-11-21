# Rôle `kubeadm`

Initialise le plan de contrôle ou joint un nœud de travail, selon `kubeadm_node_role`. Le nœud doit avoir été préparé par le rôle `kubernetes_node`.

- **Plan de contrôle** : écrit `/etc/kubernetes/kubeadm-config.yaml`, puis lance `kubeadm init` s'il n'existe pas encore de `/etc/kubernetes/admin.conf`. Le compte d'administration reçoit un kubeconfig dans `~/.kube/config`, qui ne quitte pas le nœud.
- **Nœud de travail** : s'il n'a pas de `/etc/kubernetes/kubelet.conf`, un jeton valable `kubeadm_join_token_ttl` est créé sur le plan de contrôle, puis `kubeadm join` est lancé. Ni le jeton ni la commande n'apparaissent dans les journaux (`no_log`).

La configuration (format `kubeadm.k8s.io/v1beta4`) fixe le pilote cgroup systemd, les plages des pods et des services, et ajoute `localhost` et `127.0.0.1` au certificat du serveur d'API, pour l'atteindre par une redirection de port du Bastion.

Le rôle n'a pas de scénario Molecule : kubeadm ne tourne pas dans un conteneur sans un outillage spécifique. Il est vérifié sur les nœuds réels, où deux passages successifs de `playbooks/site.yml` ne changent rien.
