# 0004. Stocker le state avec le backend oci natif

- Statut : accepté
- Date : 2026-11-20

## Contexte

Le state Terraform décrit tout ce qui existe dans la tenancy. Tant qu'il reste sur un poste, il peut être perdu avec ce poste, la CI ne peut pas lancer Terraform, et rien n'empêche deux exécutions simultanées de l'écraser l'une l'autre.

Il faut un emplacement partagé, versionné, avec un verrou, qui reste dans l'offre Always Free (20 Go d'Object Storage, voir l'[ADR 0002](0002-heberger-sur-oracle-cloud-always-free.md)).

## Options envisagées

### Backend `s3` vers l'API compatible S3 d'Object Storage

La seule option sur Oracle pendant des années. Elle demande des clés « Customer Secret » à stocker, et Oracle indique qu'elle ne fournit pas de verrouillage. Oracle la marque désormais comme dépréciée.

### HCP Terraform (offre gratuite)

State, verrou et historique gérés par HashiCorp. Mais le state, qui contient les identifiants de toutes les ressources, est stocké chez un tiers, et l'exécution dépend d'un service supplémentaire.

### Backend `oci` natif

Intégré à Terraform depuis la version 1.12. Il s'authentifie comme le provider, avec un profil `~/.oci/config`, et [verrouille le state](https://developer.hashicorp.com/terraform/language/v1.17.x/backend/oci) en créant un objet `.lock` par écriture conditionnelle (`If-None-Match: *`).

## Décision

Le backend `oci` natif, avec un bucket privé et versionné, `rtgre-platform-tfstate`. Chaque configuration du dépôt y a sa propre clé, par exemple `bootstrap/terraform.tfstate`.

Le bucket est créé par le bootstrap, qui stocke ensuite son propre state dedans.

## Conséquences

- Deux exécutions simultanées ne peuvent plus corrompre le state : la seconde échoue sur le verrou, avec une erreur 412 `IfNoneMatchFailed`. Le test a été fait le 2026-11-20.
- Le versionnage du bucket permet de revenir à un state antérieur. La procédure est décrite dans le runbook [Restaurer un state Terraform](../runbooks/restaurer-un-state-terraform.md).
- Le bootstrap dépend du bucket qu'il crée. Une reconstruction complète commence avec un state local, puis le migre dans le bucket. La procédure est décrite dans le README du bootstrap.
- Le bucket est protégé par `prevent_destroy`. Le détruire demande une modification volontaire du code.
- Aucune clé supplémentaire : le backend utilise la même authentification que le provider.
