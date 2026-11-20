# Modules

Briques réutilisables, assemblées par les configurations de `terraform/envs/`. Un module ne sait pas dans quel environnement il tourne : tout ce qui en dépend lui est passé en variable.

## Conventions

Chaque module contient :

| Fichier | Contenu |
| --- | --- |
| `versions.tf` | Versions de Terraform et des providers acceptées, sans bloc `provider` |
| `variables.tf` | Entrées, chacune avec `description`, `type` et, si utile, une `validation` |
| `main.tf` | Ressources, découpées en fichiers par sujet quand il grossit |
| `outputs.tf` | Sorties, chacune avec `description` |
| `README.md` | Rôle du module, choix notables et exemple d'appel |

Règles :

- **Aucune valeur propre à un environnement** : pas d'OCID, de plage d'adresses, de nom de région ni de taille de machine écrits en dur. Les valeurs par défaut sont réservées aux choix techniques stables, par exemple un protocole.
- **Pas de bloc `provider`** : le module hérite du provider de la configuration qui l'appelle.
- **Le compartiment et les tags sont des entrées** (`compartment_id`, `freeform_tags`) : le module les applique à toutes ses ressources.
- **Des sorties pour tout ce dont un autre module a besoin**, plutôt que des lectures croisées entre modules.
- **Des validations là où une erreur coûterait cher** : plages d'adresses, limites de l'offre gratuite.

## Modules

| Module | Rôle |
| --- | --- |
| [`network`](network) | Réseau virtuel, sous-réseaux, passerelle Internet et groupes de sécurité réseau |
| *(à venir)* `compute` | Nœuds A1 de la plateforme |
