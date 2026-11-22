# rtgre-platform

[![Quality](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/quality.yml/badge.svg)](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/quality.yml)
[![Terraform](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/terraform.yml/badge.svg)](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/terraform.yml)
[![Ansible](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/ansible.yml/badge.svg)](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/ansible.yml)
[![Security](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/security.yml/badge.svg)](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/actions/workflows/security.yml)

Infrastructure de [rtgre.fr](https://rtgre.fr), décrite en code : provisionnement avec Terraform, configuration avec Ansible, cluster Kubernetes monté avec kubeadm et déploiement en GitOps.

Le site lui-même est développé dans le dépôt [rtgre](https://github.com/kzsxwsjuldvcbsqt/rtgre). Ce dépôt ne contient que ce qui le fait tourner. rtgre construit, signe et publie l'image de son générateur sur `ghcr.io/kzsxwsjuldvcbsqt/rtgre` ; la plateforme la déploie par son empreinte, après vérification de sa signature. Le schéma de la chaîne de livraison est dans le [README de rtgre](https://github.com/kzsxwsjuldvcbsqt/rtgre#chaîne-de-livraison).

rtgre.fr est servi par cette plateforme depuis le 21 novembre 2026. GitHub Pages reste en secours : la zone DNS y revient en changeant une valeur ([runbook](docs/runbooks/basculer-rtgre-fr.md)).

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
| [`terraform/dns`](terraform/dns) | Zone DNS de rtgre.fr chez OVH, appliquée depuis le poste |
| [`ansible`](ansible) | Configuration des nœuds : inventaire dynamique, rôles et playbooks |
| [`kubernetes`](kubernetes) | Ce qui tourne dans le cluster, déployé par Argo CD : un chart par application |
| [`docs/adr`](docs/adr) | Décisions d'architecture |
| [`docs/runbooks`](docs/runbooks) | Procédures d'exploitation |
| [`docs/postmortems`](docs/postmortems) | Ce que chaque incident a appris |
| [`scripts`](scripts) | Ouverture des sessions du Bastion, tentatives d'apply sans capacité, essai d'une branche par Argo CD, aides à la CI |

## Déploiement

L'infrastructure est déployée par le workflow `Terraform` : plan commenté sur chaque pull request, puis apply du plan enregistré sur `main` après approbation dans l'environnement GitHub `production`. La CI s'authentifie auprès d'Oracle sans clé API, par échange de son jeton OIDC.

Le contenu du cluster est déployé en GitOps par Argo CD ([ADR 0010](docs/adr/0010-deployer-en-gitops-avec-argo-cd.md)). Il suit le dossier `kubernetes/` de `main` avec une clé de déploiement en lecture seule, applique chaque changement dans les minutes qui suivent sa fusion et annule toute modification manuelle. Son interface n'est pas exposée : elle s'ouvre à travers le Bastion ([runbook](docs/runbooks/acceder-a-argocd.md)).

Le trafic web entre par le Network Load Balancer gratuit d'Oracle, déclaré dans Terraform, puis par la passerelle du cluster, Traefik en contrôleur Gateway API ([ADR 0012](docs/adr/0012-exposer-par-un-network-load-balancer-et-gateway-api.md), [`kubernetes/gateway`](kubernetes/gateway)). Seuls les ports 80 et 443 du load balancer sont ouverts : les nœuds n'acceptent rien d'Internet. Les certificats viennent de Let's Encrypt, obtenus et renouvelés par cert-manager ([ADR 0013](docs/adr/0013-certificats-par-cert-manager-et-lets-encrypt.md)) ; tout le HTTP est redirigé vers HTTPS.

Prometheus collecte les métriques des nœuds et du cluster ([ADR 0015](docs/adr/0015-metriques-avec-prometheus-et-son-operateur.md), [`kubernetes/monitoring`](kubernetes/monitoring)). Grafana les affiche dans deux tableaux de bord décrits dans le dépôt, en lecture seule et sans compte ([ADR 0016](docs/adr/0016-grafana-en-lecture-seule-sans-compte.md)). Les journaux des pods sont collectés par Alloy et conservés treize jours par Loki ([ADR 0017](docs/adr/0017-journaux-avec-loki-et-alloy.md)). Comme celle d'Argo CD, ces interfaces ne s'ouvrent qu'à travers le Bastion.

Treize règles d'alerte, testées dans la CI, préviennent le propriétaire par courrier : site injoignable, génération en échec, certificat non renouvelé, nœud saturé, pod en boucle, application désynchronisée, journaux gardés trop longtemps ([ADR 0018](docs/adr/0018-alertes-avec-alertmanager-et-telegram.md), [ADR 0021](docs/adr/0021-envoyer-les-alertes-par-courrier.md)). Chaque message renvoie au [runbook](docs/runbooks) de l'alerte. Comme ces alertes partent du cluster qu'elles surveillent, deux alarmes d'Oracle veillent du dehors : elles préviennent par courrier quand plus aucun nœud ne répond derrière le load balancer ([ADR 0024](docs/adr/0024-surveiller-le-load-balancer-par-une-alarme-d-oracle.md)). Le workflow `Watch` interroge aussi le site depuis GitHub et ouvre une issue « Incident » s'il ne répond plus, quand GitHub le lance ([ADR 0022](docs/adr/0022-surveiller-le-site-depuis-github-actions.md)).

Dans l'espace de noms du site, le cluster contrôle lui-même chaque pod à sa création : ses images viennent de dépôts déclarés, portent leur empreinte, et celle du site doit être signée par le workflow qui la construit ([ADR 0019](docs/adr/0019-controler-les-images-a-l-admission-avec-kyverno.md), [`kubernetes/kyverno`](kubernetes/kyverno)).

L'audience du site est mesurée par Umami, sans cookie : seule la collecte est exposée, sous le nom du site, et le tableau de bord ne s'ouvre que par le Bastion ([ADR 0025](docs/adr/0025-mesurer-l-audience-avec-umami.md), [`kubernetes/umami`](kubernetes/umami)).

Le site est généré dans le cluster par l'image que publie le dépôt rtgre ([`kubernetes/rtgre`](kubernetes/rtgre)). Quand rtgre publie une nouvelle image, Renovate propose sa nouvelle empreinte et la fusionne de lui-même une fois la CI verte : celle-ci vérifie que l'image est signée par le workflow de rtgre.

## Dépendances

Toutes les versions sont épinglées : outils dans `mise.toml`, providers Terraform, hooks pre-commit, actions GitHub par SHA, dépendances d'Ansible, images de test par empreinte, Kubernetes, Cilium et le chart d'Argo CD.

- **Renovate** (`renovate.json`) propose les mises à jour, regroupées par écosystème, chaque lundi matin. Les correctifs de sécurité arrivent sans attendre. Une montée mineure de Kubernetes, de Cilium ou d'Argo CD attend une approbation dans le tableau de bord des dépendances, car leur compatibilité doit être vérifiée ([ADR 0009](docs/adr/0009-reseau-des-pods-avec-cilium.md), [ADR 0010](docs/adr/0010-deployer-en-gitops-avec-argo-cd.md)).
- **Les alertes Dependabot** signalent une vulnérabilité publiée sur une dépendance en place.
- **Le workflow `Security`** analyse chaque lundi, avec Trivy, les dépendances et chaque image que le cluster déploie.

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
| Trivy | Mauvaises configurations (Terraform, Dockerfile), vulnérabilités des dépendances et de chaque image déployée par `kubernetes/` (`mise run images-scan`), HIGH et CRITICAL bloquantes ; exceptions justifiées et datées dans `.trivyignore.yaml` |
| conventional-pre-commit | Format des messages de commit |
| Molecule | Rôles Ansible, dans un conteneur Ubuntu 24.04 |
| helm lint, kubeconform | Charts de `kubernetes/`, rendus pour la version de Kubernetes du cluster (`mise run kubernetes-validate`) |
| cosign | Signature des images listées dans `kubernetes/kyverno/files/signed-images.txt`, avant tout déploiement |
| promtool, amtool | Règles d'alerte et leurs tests, configuration d'Alertmanager, existence du runbook de chaque alerte |

Les contrôles sont décrits dans `.pre-commit-config.yaml` et s'exécutent avant chaque commit une fois les hooks installés :

```bash
pre-commit install
```

Le workflow `Security` relance Trivy sur chaque pull request et chaque lundi : une vulnérabilité peut être publiée sur une dépendance inchangée. Le workflow `Quality` relance les mêmes contrôles sur chaque pull request, analyse tout l'historique à la recherche de secrets et vérifie que chaque message de commit suit [Conventional Commits](https://www.conventionalcommits.org/fr/).

## Contribuer

La façon de travailler, le format des messages de commit et la signature sont décrits dans [CONTRIBUTING.md](CONTRIBUTING.md). Une vulnérabilité se signale en privé : voir [SECURITY.md](SECURITY.md).
