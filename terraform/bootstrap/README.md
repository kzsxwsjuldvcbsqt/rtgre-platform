# Bootstrap

Socle de la tenancy Oracle Cloud, appliqué une fois avant tout le reste :

- l'espace de tags `rtgre-platform`, avec les tags `project` et `environment` ;
- le compartiment `rtgre-platform-prod`, qui accueille toutes les ressources de la plateforme ;
- l'application par défaut de ces tags à toute ressource créée dans le compartiment ;
- un budget mensuel sur toute la tenancy, qui alerte par e-mail dès la première dépense réelle et quand la prévision du mois dépasse le budget ;
- le bucket privé et versionné `rtgre-platform-tfstate`, qui conserve le state de toutes les configurations Terraform, celui du bootstrap compris ;
- l'identité de la CI : un utilisateur de service en lecture seule sur le compartiment, que GitHub Actions emprunte en échangeant son jeton OIDC (voir l'[ADR 0005](../../docs/adr/0005-authentifier-la-ci-par-federation-d-identite.md)).

## Prérequis

- Les outils de `mise.toml`, installés avec `mise install`.
- Une clé API Oracle déclarée pour un utilisateur administrateur de la tenancy, et le profil correspondant dans `~/.oci/config`. La clé privée ne quitte jamais le poste.

## Utilisation

Depuis ce dossier, préparer les deux fichiers locaux, qui ne sont pas suivis par Git :

```bash
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
```

Renseigner `tenancy_ocid`, `budget_alert_recipients` et `github_repository` dans `terraform.tfvars`, et le namespace Object Storage dans `backend.hcl` (`oci os ns get`).

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Un second `terraform plan` doit annoncer « No changes ».

## Raccorder GitHub Actions

Après l'apply, déposer dans le dépôt GitHub les informations de connexion de la CI. Le secret est envoyé directement à GitHub, sans passer par l'écran :

```bash
gh variable set OCI_DOMAIN_URL --body "$(terraform output -raw identity_domain_url | sed 's/:443$//')"
gh variable set OCI_CLIENT_ID --body "$(terraform output -raw ci_token_exchange_client_id)"
gh variable set OCI_TENANCY_OCID --body "<OCID de la tenancy>"
gh variable set OCI_REGION --body "eu-paris-1"
gh variable set OCI_STATE_BUCKET --body "$(terraform output -raw state_bucket)"
terraform output -raw ci_token_exchange_client_secret | gh secret set OCI_CLIENT_SECRET
```

Le workflow `Oracle access` vérifie ensuite que la CI peut lire le bucket du state, mais ni y écrire ni lire la racine de la tenancy.

## Reconstruction depuis une tenancy vide

Le state du bootstrap vit dans le bucket que le bootstrap crée. Sur une tenancy vide, il faut donc partir d'un state local :

1. Forcer un backend local avec un fichier d'override, ignoré par Git :

   ```bash
   printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
   terraform init
   terraform apply
   ```

2. Supprimer l'override, puis migrer le state dans le bucket qui vient d'être créé :

   ```bash
   rm backend_override.tf
   terraform init -backend-config=backend.hcl -migrate-state
   ```

3. Une fois `terraform plan` vide, supprimer les fichiers `terraform.tfstate*` locaux.

## Points d'attention

- Oracle refuse un tag dans les secondes qui suivent sa création. `time_sleep.tag_propagation` attend `tag_propagation_delay` (30 s par défaut) avant d'utiliser les tags.
- Oracle pose les tags `Oracle-Tags.CreatedBy` et `CreatedOn` sur le compartiment. Ils sont ignorés pour ne pas créer d'écart à chaque plan.
- Le budget mesure le coût d'usage avant les crédits d'essai : une ressource hors de l'offre Always Free déclenche l'alerte même si les crédits la paient. Oracle évalue les budgets environ toutes les heures, l'alerte n'est donc pas instantanée.
- L'API des budgets stocke les caractères accentués sous forme d'entités HTML (`&eacute;`). La description du budget est écrite sans accent pour éviter un écart permanent dans le plan.
- Pour les ressources du domaine d'identité, l'API ne renvoie les membres d'un groupe et les règles d'emprunt qu'avec `attribute_sets = ["all"]`, et Oracle ajoute à `schemas` des extensions qui varient : ce champ est ignoré.
- La règle d'emprunt d'une confiance attend l'identifiant SCIM de l'utilisateur. Avec son OCID, l'API refuse la valeur (40 caractères au plus).
- Le state est verrouillé pendant chaque exécution. Pour un verrou bloqué ou un state à restaurer, voir le runbook [Restaurer un state Terraform](../../docs/runbooks/restaurer-un-state-terraform.md).
- Le bucket du state est protégé par `prevent_destroy`. Un `destroy` complet demande de retirer volontairement cette protection.
- La suppression d'un compartiment prend du temps côté Oracle, et un espace de tags doit être retiré avant de pouvoir être supprimé : un `destroy` complet n'est pas instantané.
