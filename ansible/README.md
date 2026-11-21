# Ansible

Configuration des nœuds créés par Terraform : durcissement, runtime de conteneurs, puis cluster Kubernetes avec kubeadm.

## Installation

Depuis la racine du dépôt :

```bash
mise install
mise run ansible-deps
```

`mise install` installe Python 3.13 et crée l'environnement virtuel `.venv`. `mise run ansible-deps` y installe ansible-core, ansible-lint, Molecule et le SDK Oracle aux versions de `requirements.txt`, puis les collections de `requirements.yml` dans `ansible/collections/`, qui n'est pas suivi par Git.

Les commandes suivantes se lancent depuis ce dossier, pour que `ansible.cfg` soit pris en compte.

## Inventaire

Les nœuds ne sont jamais écrits à la main. `inventories/prod/nodes.oci.yml` les lit dans Oracle Cloud à chaque exécution, avec le profil `~/.oci/config` :

- seules les instances en marche portant le tag `stack = envs/prod`, posé par Terraform, sont retenues ;
- chaque hôte prend le nom de son label réseau (`cp-1`, `wk-1`) ;
- les groupes `k8s_control_plane` et `k8s_worker` viennent du tag `kubernetes-role` posé par le module `compute`.

```bash
ansible-inventory --graph
```

Le plugin `oracle.oci.oci` n'accepte que les fichiers dont le nom se termine par `.oci.yml`.

## Configurer les nœuds

Les nœuds ne sont joignables que par le Bastion. Il faut d'abord ouvrir les sessions (voir le runbook [Se connecter à un nœud](../docs/runbooks/se-connecter-a-un-noeud.md)), puis, depuis ce dossier :

```bash
ansible-playbook playbooks/site.yml
```

Le playbook vérifie d'abord les plages réseau déclarées dans `inventories/prod/group_vars/all.yml`, applique `hardening` et `kubernetes_node` à tous les nœuds, initialise le plan de contrôle, installe Cilium, joint les nœuds de travail, puis attend qu'ils soient tous prêts. Relancé sur un cluster en place, il ne change rien. Pour une modification risquée, l'appliquer d'abord à un seul nœud avec `--limit wk-1`.

## Utiliser kubectl

kubectl est disponible sur le plan de contrôle, pour le compte d'administration :

```bash
ssh -F .ssh/bastion.conf cp-1 kubectl get nodes
```

Le kubeconfig d'administration ne quitte pas le nœud.

## Rôles

| Rôle | Rôle dans la plateforme |
| --- | --- |
| [`hardening`](roles/hardening) | Socle de sécurité : SSH, pare-feu, mises à jour, noyau |
| [`kubernetes_node`](roles/kubernetes_node) | Préparation pour kubeadm : noyau, containerd, paquets Kubernetes |
| [`local_volumes`](roles/local_volumes) | Dossiers des volumes persistants locaux portés par le nœud |
| [`kubeadm`](roles/kubeadm) | Initialisation du plan de contrôle et jonction des nœuds |
| [`cilium`](roles/cilium) | Réseau des pods (CNI) |
| [`argocd`](roles/argocd) | Amorçage d'Argo CD, de sa clé de déploiement et de son application racine |

Les rôles qui configurent un nœud seul, `hardening`, `kubernetes_node` et `local_volumes`, ont un scénario Molecule (`roles/<rôle>/molecule/default`), lancé en local avec `molecule test` depuis le dossier du rôle, et dans la CI par le workflow `Ansible`. Molecule a besoin de Docker et de `rsync`. Les rôles `kubeadm`, `cilium` et `argocd` ont besoin d'un vrai cluster : ils sont contrôlés par ansible-lint, puis vérifiés sur les nœuds.

## Qualité

`ansible-lint`, avec le profil `production`, tourne dans pre-commit et dans la CI. Il crée un cache dans `ansible/.ansible/`, ignoré par Git.
