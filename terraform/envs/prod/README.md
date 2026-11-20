# Prod

Configuration de l'environnement de production. Elle assemble les modules de `terraform/modules` dans le compartiment créé par le [bootstrap](../../bootstrap).

Le compartiment et l'espace de tags sont lus dans le state du bootstrap avec `terraform_remote_state` : aucun OCID n'est recopié ici.

## Prérequis

- Le bootstrap appliqué, avec son state dans le bucket `rtgre-platform-tfstate`.
- Les outils de `mise.toml`, et un profil `~/.oci/config` autorisé à lire ce bucket.

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
