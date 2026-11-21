# rtgre-platform

Infrastructure de [rtgre.fr](https://rtgre.fr), décrite en code : provisionnement avec Terraform, configuration avec Ansible, cluster Kubernetes monté avec kubeadm et déploiement en GitOps.

Le site lui-même est développé dans le dépôt [rtgre](https://github.com/kzsxwsjuldvcbsqt/rtgre). Ce dépôt ne contient que ce qui le fait tourner.

Projet en construction.

## Prérequis

Les versions des outils sont fixées dans `mise.toml`. Avec [mise](https://mise.jdx.dev) installé, une seule commande installe exactement les mêmes depuis la racine du dépôt :

```bash
mise install
mise run ansible-deps
```

La seconde commande installe les dépendances Python et les collections d'Ansible dans le dépôt.

## Organisation

| Dossier | Rôle |
| --- | --- |
| [`terraform/bootstrap`](terraform/bootstrap) | Socle de la tenancy : compartiment, tags, budget, bucket du state, identité de la CI |
| [`terraform/envs/prod`](terraform/envs/prod) | Environnement de production, assemblé à partir des modules |
| [`terraform/modules`](terraform/modules) | Modules réutilisables et leurs conventions |
| [`ansible`](ansible) | Configuration des nœuds : inventaire dynamique, rôles et playbooks |
| [`docs/adr`](docs/adr) | Décisions d'architecture |
| [`docs/runbooks`](docs/runbooks) | Procédures d'exploitation |

## Déploiement

La prod est déployée par le workflow `Terraform` : plan commenté sur chaque pull request, puis apply du plan enregistré sur `main` après approbation dans l'environnement GitHub `production`. La CI s'authentifie auprès d'Oracle sans clé API, par échange de son jeton OIDC.

## Qualité

Les contrôles sont décrits dans `.pre-commit-config.yaml` et s'exécutent avant chaque commit une fois les hooks installés :

```bash
pre-commit install
```

Le workflow `Quality` relance les mêmes contrôles sur chaque pull request, analyse tout l'historique à la recherche de secrets et vérifie que chaque message de commit suit [Conventional Commits](https://www.conventionalcommits.org/fr/).
