# 0008. Passer en paiement à l'usage, sous quotas

- Statut : accepté
- Date : 2026-11-21

## Contexte

Depuis le 2026-11-20, chaque tentative de création des deux nœuds A1 échoue avec `500-InternalError, Out of host capacity` : la région de Paris n'a plus de capacité ARM pour les comptes gratuits. Le runbook [Créer des nœuds A1 sans capacité disponible](../runbooks/creer-des-noeuds-sans-capacite-a1.md) prévoyait, après plusieurs échecs, de passer la tenancy en paiement à l'usage. Selon des retours d'utilisateurs, ces comptes sont prioritaires pour la capacité A1 ; Oracle ne l'a pas confirmé publiquement.

En paiement à l'usage, les ressources Always Free restent gratuites, et seul ce qui dépasse l'offre est facturé. Le risque est donc une erreur, humaine ou de code, qui crée une ressource payante. Jusqu'ici, deux garde-fous le limitaient :

- les validations Terraform du module `compute` (OCPU, mémoire, volumes) ;
- l'alerte de budget dès 0,01 € de dépense réelle.

Ni l'un ni l'autre n'empêche une ressource payante d'être créée : la validation ne couvre que ce que déclare Terraform, et l'alerte arrive après la dépense.

## Options envisagées

### Rester en offre gratuite et attendre

Aucun risque de facturation. Mais rien n'indique quand la capacité reviendra, et tout ce qui suit (cluster, application, bascule de rtgre.fr) attend.

### Changer de région

Impossible : la région de rattachement d'une tenancy ne change pas, et les ressources Always Free n'existent que dans celle-ci.

### Paiement à l'usage, sous quotas

Des quotas Oracle limitent toute la tenancy aux ressources de l'offre gratuite. Oracle refuse alors une création hors de ces limites, quelle que soit son origine : Terraform, console ou CLI.

## Décision

La tenancy passe en paiement à l'usage, après la pose de quotas en liste blanche (`terraform/bootstrap/quotas.tf`) :

- chaque famille concernée (cœurs, mémoire, stockage bloc, bases de données) est mise à zéro ;
- seules les ressources gratuites sont ensuite autorisées, à hauteur de l'offre : ARM A1 (2 OCPU et 12 Go, par domaine de disponibilité et par région), 200 Go de stockage bloc, 5 sauvegardes, 20 Go de stockage objet.

Les limites sont dans `terraform/bootstrap/free-tier.auto.tfvars`, avec leur source et leur date.

## Conséquences

- Une forme payante est refusée avant toute facturation. Vérifié le 2026-11-21 avec `oci limits resource-availability get` : 0 disponible pour les formes E2 Micro, E4, E5 et Standard3, 2 OCPU et 12 Go pour A1.
- Si Oracle confirme un jour 4 OCPU et 24 Go gratuits pour les comptes en paiement à l'usage, il suffira de relever les quotas, la validation Terraform et les nœuds, après vérification sur la facture.
- Les familles sans quota (load balancers, réseau) ne sont pas encore verrouillées. Le load balancer flexible gratuit n'a pas de nom de quota documenté : son quota sera posé et vérifié avec sa création, en phase 4. Jusque-là, l'alerte de budget reste le seul garde-fou pour ces familles.
- Un quota trop strict bloque aussi les ressources légitimes : le premier jeu de quotas oubliait les limites régionales des ARM, et la création des nœuds a été refusée (`400-QuotaExceeded`) jusqu'à leur ajout.
- Le passage en paiement à l'usage se fait dans la console et demande une carte bancaire : c'est la seule étape qui ne soit pas décrite en code.
