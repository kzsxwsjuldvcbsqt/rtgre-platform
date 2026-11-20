# rtgre-platform

Infrastructure de [rtgre.fr](https://rtgre.fr), décrite en code : provisionnement avec Terraform, configuration avec Ansible, cluster Kubernetes monté avec kubeadm et déploiement en GitOps.

Le site lui-même est développé dans le dépôt [rtgre](https://github.com/kzsxwsjuldvcbsqt/rtgre). Ce dépôt ne contient que ce qui le fait tourner.

Projet en construction.

## Prérequis

Les versions des outils sont fixées dans `mise.toml`. Avec [mise](https://mise.jdx.dev) installé, une seule commande installe exactement les mêmes depuis la racine du dépôt :

```bash
mise install
```

## Qualité

Les contrôles sont décrits dans `.pre-commit-config.yaml` et s'exécutent avant chaque commit une fois les hooks installés :

```bash
pre-commit install
```

Le workflow `Quality` relance les mêmes contrôles sur chaque pull request, analyse tout l'historique à la recherche de secrets et vérifie que chaque message de commit suit [Conventional Commits](https://www.conventionalcommits.org/fr/).
