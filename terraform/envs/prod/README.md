# Prod

Configuration de l'environnement de production. Elle assemble les modules de `terraform/modules` dans le compartiment créé par le [bootstrap](../../bootstrap).

Le compartiment et l'espace de tags sont lus dans le state du bootstrap avec `terraform_remote_state` : aucun OCID n'est recopié ici.

## Prérequis

- Le bootstrap appliqué, avec son state dans le bucket `rtgre-platform-tfstate`.
- Les outils de `mise.toml`, et un profil `~/.oci/config` autorisé à lire ce bucket.

## Paramètres

| Fichier | Suivi par Git | Contenu |
| --- | --- | --- |
| `prod.auto.tfvars` | oui | Paramètres de l'environnement : nom, plages d'adresses, plages autorisées |
| `terraform.tfvars` | non | Ce qui dépend du poste : région, authentification, namespace |
| `backend.hcl` | non | Emplacement du state |

## Utilisation

Depuis ce dossier, préparer les deux fichiers locaux, qui ne sont pas suivis par Git :

```bash
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

Renseigner le namespace Object Storage dans les deux fichiers (`oci os ns get`), puis :

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=prod.tfplan
terraform apply prod.tfplan
```

## Authentification

| Contexte | `oci_auth` | Profil |
| --- | --- | --- |
| Poste administrateur | `APIKey` | clé API dans `~/.oci/config` |
| GitHub Actions | `SecurityToken` | profil écrit par `.github/actions/oci-login` |

Le backend et `terraform_remote_state` utilisent la même authentification que le provider.

## Déploiement par la CI

Le workflow `Terraform` décrit dans l'[ADR 0007](../../../docs/adr/0007-appliquer-la-prod-depuis-la-ci-apres-approbation.md) :

1. sur chaque pull request qui touche la prod ou les modules, il publie le plan en commentaire ;
2. après la fusion, il recalcule le plan sur `main` et l'enregistre ;
3. s'il y a des changements, le job `Apply (prod)` attend une approbation dans l'onglet Actions, puis applique ce plan tel quel.

En CI, la région, le bucket et le namespace viennent des variables du dépôt (`OCI_REGION`, `OCI_STATE_BUCKET`) et d'Oracle : `terraform.tfvars` et `backend.hcl` ne servent qu'au poste.
