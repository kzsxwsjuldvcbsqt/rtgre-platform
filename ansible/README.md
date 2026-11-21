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

## Rôles

| Rôle | Rôle dans la plateforme |
| --- | --- |
| [`hardening`](roles/hardening) | Socle de sécurité : SSH, pare-feu, mises à jour, noyau |

Chaque rôle a un scénario Molecule (`roles/<rôle>/molecule/default`), lancé en local avec `molecule test` depuis le dossier du rôle, et dans la CI par le workflow `Ansible`. Molecule a besoin de Docker et de `rsync`.

## Qualité

`ansible-lint`, avec le profil `production`, tourne dans pre-commit et dans la CI. Il crée un cache dans `ansible/.ansible/`, ignoré par Git.
