# Rôle `kubernetes_node`

Prépare un nœud Ubuntu 24.04 pour kubeadm, sans initialiser ni joindre de cluster.

| Domaine | Ce que fait le rôle |
| --- | --- |
| Noyau | Modules `overlay` et `br_netfilter` déclarés au démarrage et chargés, routage IPv4 et filtrage des ponts activés (`/etc/sysctl.d/70-kubernetes.conf`), swap désactivé. |
| containerd | Paquet de l'archive Ubuntu (2.2 sur Ubuntu 24.04), configuré au format 3 : pilote cgroup systemd pour runc, image pause épinglée. `crictl` pointe sur son socket. |
| Kubernetes | kubeadm, kubelet et kubectl à la version exacte `kubernetes_node_version` (1.36.6 par défaut, voir l'ADR 0009), depuis `pkgs.k8s.io`, puis bloqués. Une version plus ancienne que celle installée peut être imposée. `cri-tools` est installé dans la même version mineure. |

## Choix notables

- **containerd vient d'Ubuntu**, pas du dépôt de Docker : il reste couvert par les mises à jour de sécurité de l'archive, et il n'est pas bloqué.
- **La configuration de containerd est minimale** : elle n'écrit que ce qui diffère des défauts. Le format 3 de containerd 2.x n'utilise plus les chemins des tutoriels écrits pour containerd 1.x (`io.containerd.grpc.v1.cri`).
- **Les paquets Kubernetes sont bloqués** (`apt-mark hold`) : une montée de version passe par `kubeadm upgrade`, nœud par nœud, jamais par `unattended-upgrades`.
- **L'image pause suit kubeadm** : le test Molecule la compare à `kubeadm config images list`, et échoue si une montée de version de Kubernetes en change.
- **`cri-tools` est installé explicitement** : kubeadm n'en dépend plus, mais `crictl` reste l'outil de diagnostic du runtime.

## Exemple

```yaml
- name: Prepare the nodes for kubeadm
  hosts: all
  become: true
  roles:
    - role: kubernetes_node
      vars:
        kubernetes_node_version: "1.36.6"
```

## Tests

```bash
cd ansible/roles/kubernetes_node
molecule test
```

Le scénario tourne dans le même conteneur Ubuntu 24.04 avec systemd que le rôle `hardening`. Il vérifie :

- la version et le blocage des paquets ;
- la configuration effective de containerd (`containerd config dump`) ;
- la réponse du socket CRI (`crictl info`) ;
- l'accord entre l'image pause et kubeadm ;
- les fichiers noyau.

Modules, paramètres noyau et swap ne sont pas appliqués dans le conteneur : il partage le noyau de la machine hôte.
