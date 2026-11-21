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
| [`scripts`](scripts) | Ouverture des sessions du Bastion, tentatives d'apply sans capacité, aides à la CI |

## Déploiement

La prod est déployée par le workflow `Terraform` : plan commenté sur chaque pull request, puis apply du plan enregistré sur `main` après approbation dans l'environnement GitHub `production`. La CI s'authentifie auprès d'Oracle sans clé API, par échange de son jeton OIDC.

## Dépendances

Toutes les versions sont épinglées : outils dans `mise.toml`, providers Terraform, hooks pre-commit, actions GitHub par SHA, dépendances d'Ansible, images de test par empreinte, Kubernetes et Cilium.

- **Renovate** (`renovate.json`) propose les mises à jour, regroupées par écosystème, chaque lundi matin. Les correctifs de sécurité arrivent sans attendre. Une montée mineure de Kubernetes ou de Cilium attend une approbation dans le tableau de bord des dépendances, car leur compatibilité doit être vérifiée ([ADR 0009](docs/adr/0009-reseau-des-pods-avec-cilium.md)).
- **Les alertes Dependabot** signalent une vulnérabilité publiée sur une dépendance en place.
- **Le workflow `Security`** analyse chaque lundi les dépendances avec Trivy.

## Qualité

| Outil | Ce qu'il vérifie |
| --- | --- |
| gitleaks | Secrets, dans les fichiers indexés et dans tout l'historique |
| terraform fmt, validate, tflint | Code Terraform |
| ansible-lint (profil `production`) | Code Ansible |
| yamllint | Fichiers YAML |
| zizmor, actionlint | Sécurité et validité des workflows GitHub Actions |
| ShellCheck | Scripts shell et blocs `run` des workflows |
| Checkov | Terraform, dont les règles propres à Oracle Cloud (`CKV_OCI_*`) ; exceptions justifiées dans le code |
| Trivy | Mauvaises configurations (Terraform, Dockerfile) et vulnérabilités des dépendances, HIGH et CRITICAL bloquantes ; exceptions datées dans `.trivyignore.yaml` |
| conventional-pre-commit | Format des messages de commit |
| Molecule | Rôles Ansible, dans un conteneur Ubuntu 24.04 |

Les contrôles sont décrits dans `.pre-commit-config.yaml` et s'exécutent avant chaque commit une fois les hooks installés :

```bash
pre-commit install
```

Le workflow `Security` relance Trivy sur chaque pull request et chaque lundi : une vulnérabilité peut être publiée sur une dépendance inchangée. Le workflow `Quality` relance les mêmes contrôles sur chaque pull request, analyse tout l'historique à la recherche de secrets et vérifie que chaque message de commit suit [Conventional Commits](https://www.conventionalcommits.org/fr/).
