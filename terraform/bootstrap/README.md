# Bootstrap

Socle de la tenancy Oracle Cloud, appliqué une fois avant tout le reste :

- l'espace de tags `rtgre-platform`, avec les tags `project` et `environment` ;
- le compartiment `rtgre-platform-prod`, qui accueille toutes les ressources de la plateforme ;
- l'application par défaut de ces tags à toute ressource créée dans le compartiment ;
- un budget mensuel sur toute la tenancy, qui alerte par e-mail dès la première dépense réelle et quand la prévision du mois dépasse le budget.

## Prérequis

- Les outils de `mise.toml`, installés avec `mise install`.
- Une clé API Oracle déclarée pour un utilisateur administrateur de la tenancy, et le profil correspondant dans `~/.oci/config`. La clé privée ne quitte jamais le poste.

## Utilisation

Depuis ce dossier :

```bash
cp terraform.tfvars.example terraform.tfvars
```

Renseigner ensuite `tenancy_ocid` et `budget_alert_recipients` dans `terraform.tfvars`. Ce fichier n'est pas suivi par Git.

```bash
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Un second `terraform plan` doit annoncer « No changes ».

## Points d'attention

- Oracle refuse un tag dans les secondes qui suivent sa création. `time_sleep.tag_propagation` attend `tag_propagation_delay` (30 s par défaut) avant d'utiliser les tags.
- Oracle pose les tags `Oracle-Tags.CreatedBy` et `CreatedOn` sur le compartiment. Ils sont ignorés pour ne pas créer d'écart à chaque plan.
- Le budget mesure le coût d'usage avant les crédits d'essai : une ressource hors de l'offre Always Free déclenche l'alerte même si les crédits la paient. Oracle évalue les budgets environ toutes les heures, l'alerte n'est donc pas instantanée.
- L'API des budgets stocke les caractères accentués sous forme d'entités HTML (`&eacute;`). La description du budget est écrite sans accent pour éviter un écart permanent dans le plan.
- Le state est pour l'instant local. Il sera déplacé dans Object Storage avec l'issue #5.
- La suppression d'un compartiment prend du temps côté Oracle, et un espace de tags doit être retiré avant de pouvoir être supprimé : un `destroy` complet n'est pas instantané.
