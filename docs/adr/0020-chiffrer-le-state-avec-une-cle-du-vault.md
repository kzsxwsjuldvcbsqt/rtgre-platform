# 0020. Chiffrer le state avec une clé du Vault

- Statut : accepté
- Date : 2026-11-22

## Contexte

Le bucket `rtgre-platform-tfstate` porte le state de toute la plateforme : identifiants de chaque ressource, et quelques secrets. Il était chiffré au repos par une clé qu'Oracle gère seul. Le propriétaire ne pouvait ni la désactiver ni la remplacer, et Checkov le signalait (`CKV_OCI_9`).

Les contraintes :

- rester dans l'offre gratuite, sans chemin possible vers une facture ([ADR 0008](0008-passer-en-paiement-a-l-usage-sous-quotas.md)) ;
- ne pas donner de droit supplémentaire à la CI ;
- le bootstrap garde son propre state dans ce bucket.

## Options envisagées

### Garder la clé gérée par Oracle

Rien à faire, rien à perdre. Aucun contrôle sur la clé.

### Une clé du Vault protégée par HSM

La clé ne quitte jamais un module matériel. Les vingt premières versions de clé de la tenancy sont gratuites, les suivantes facturées, et aucun quota ne permet de s'arrêter à vingt.

### Une clé du Vault protégée par logiciel

La clé est gardée par le service, hors module matériel. Toutes ses versions sont gratuites, sans limite.

## Décision

Une clé AES de 256 bits protégée par logiciel, dans un Vault du type par défaut, déclarés dans le bootstrap.

- **Gratuite sans condition** : renouveler la clé autant de fois qu'on veut ne coûte rien. Un quota limite la tenancy à un Vault, et le Vault privé, payant, reste à zéro.
- **Une politique pour un seul usage** : le service Object Storage de la région peut utiliser cette clé, et aucune autre. Ni le poste ni la CI n'ont de droit sur elle : Object Storage chiffre et déchiffre en leur nom.
- **Les objets déjà présents ont été rechiffrés** le 22 novembre 2026. Associer une clé à un bucket ne touche que les objets écrits ensuite.

## Conséquences

- Le propriétaire peut désactiver la clé, ce qui coupe aussitôt tout accès au state, ou la renouveler.
- **Perdre la clé, c'est perdre le state.** Terraform refuse de supprimer le Vault et la clé, et Oracle ne les supprime qu'après un délai de sept jours au moins, pendant lequel la suppression s'annule.
- Pour la même raison, le Vault ne se retire pas en un jour : revenir à la clé gérée par Oracle demande de rechiffrer le bucket d'abord.
- Vérifié à la mise en service : le poste relit les states du bootstrap et du DNS, et la CI celui de la prod (`No changes`), avec son identité en lecture seule.
- La protection par logiciel est moins forte que par HSM. Le risque couvert ici est l'absence de contrôle sur la clé, pas le vol de la clé chez Oracle.
- L'exception `CKV_OCI_9` de Checkov est retirée.
