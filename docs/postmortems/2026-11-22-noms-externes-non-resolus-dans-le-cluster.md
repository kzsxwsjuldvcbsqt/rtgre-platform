# 2026-11-22. Noms externes non résolus dans le cluster : rien pour les visiteurs

- Issue : #115
- Durée : de 16 h 01 à 16 h 09, heure de Paris
- Détecté par : l'essai de la sauvegarde, avant fusion

## Résumé

Pendant l'essai de la sauvegarde d'Umami sur le cluster, une règle réseau destinée à fermer le service de métadonnées d'Oracle a aussi fermé le résolveur DNS d'Oracle, qui a la même adresse. Pendant huit minutes, aucun pod n'a pu résoudre un nom hors du cluster. Le site est resté servi.

## Impact

Aucun pour les visiteurs : le site et la collecte d'audience ont répondu tout du long. Dans le cluster, la génération de 16 h 07 a attendu ADE trois minutes avant de réussir, et Argo CD n'a plus joint le dépôt. Aucun certificat n'était à renouveler et aucune alerte à envoyer pendant ces huit minutes.

## Chronologie

| Heure | Événement |
| --- | --- |
| 16 h 01 | Argo CD applique la branche à l'essai, et avec elle la règle `instance-identity` : tout accès des pods à `169.254.169.254` est refusé. |
| 16 h 02 | La première sauvegarde échoue : le pod ne résout pas le nom du service d'authentification d'Oracle. |
| 16 h 06 | Un pod d'essai montre que plus aucun nom externe n'est résolu : CoreDNS n'atteint plus le résolveur d'Oracle. |
| 16 h 07 | La règle est supprimée à la main. Argo CD la recrée aussitôt telle qu'il la connaît : sans DNS, il ne peut pas lire la correction poussée dans le dépôt. |
| 16 h 09 | La règle est corrigée à la main, limitée au port 80. Argo CD retrouve le dépôt et applique la même correction. Retour à la normale. |
| 16 h 10 | La génération du site réussit, et la sauvegarde aussi. |

## Cause

Chez Oracle, `169.254.169.254` est à la fois le service de métadonnées, sur le port 80, et le résolveur DNS du réseau, sur le port 53. La règle refusait l'adresse entière.

Elle avait été essayée avant d'être écrite dans le chart, mais sur des pods d'essai seulement : ils ont gardé leur accès à Internet, et rien ne montrait que CoreDNS, lui, serait touché.

## Ce qui a bien fonctionné

- L'essai sur le cluster avant fusion : la règle n'a jamais atteint `main`.
- Le site ne dépend d'aucun nom externe pour répondre : les visiteurs n'ont rien vu.
- Le générateur réessaie de lui-même : la génération a seulement pris du retard.

## Actions

| Action | Suivi |
| --- | --- |
| La règle ne refuse que le port 80, celui du service de métadonnées, et le dit dans son commentaire. | Fait, dans la même pull request |
| Une règle qui vaut pour tout le cluster s'essaie sur tout le cluster : après l'avoir posée, vérifier qu'un pod ordinaire résout encore un nom externe. | Fait pour celle-ci ; noté dans le [README de `kubernetes/umami`](../../kubernetes/umami/README.md) |
| Quand le DNS du cluster tombe, Argo CD ne peut plus lire sa propre correction : la corriger à la main, puis le laisser reprendre. | Noté ici ; rien à changer |
