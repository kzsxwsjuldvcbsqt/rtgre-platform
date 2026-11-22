# 2026-11-22. Certificat invalide au retour de la reconstruction

- Issue : #100
- Durée : de 12 h 11 à 12 h 17, heure de Paris
- Détecté par : la vérification prévue pendant l'exercice

## Résumé

À la fin de l'exercice de reconstruction, les visiteurs ont été ramenés vers le cluster neuf avant que son certificat n'existe. Pendant cinq minutes, le cluster a répondu avec un certificat par défaut, que les navigateurs refusent. Le certificat aurait dû arriver en une minute : cert-manager attendait que le résolveur du cluster oublie l'adresse de GitHub Pages, gardée une heure.

## Impact

Un visiteur dont le résolveur DNS donnait déjà l'adresse du cluster voyait une erreur de certificat. La zone venait de porter les adresses de GitHub Pages avec une durée de vie d'une heure : la plupart des visiteurs les gardaient en cache et ont continué d'être servis par GitHub Pages. Leur nombre n'a pas été mesuré.

## Chronologie

| Heure | Événement |
| --- | --- |
| 11 h 20 | Visiteurs renvoyés sur GitHub Pages, avant l'exercice. |
| 11 h 37 | Destruction des deux nœuds. |
| 12 h 06 | Cluster reconstruit. cert-manager demande le certificat : `test.rtgre.fr` est validé, `rtgre.fr` et `www.rtgre.fr` restent en attente, car ils désignent GitHub Pages. |
| 12 h 11 | Visiteurs ramenés vers le cluster, pour que les deux noms puissent être validés. Le cluster sert un certificat par défaut. |
| 12 h 15 | Les défis sont toujours en attente : la vérification préalable de cert-manager reçoit encore la réponse de GitHub Pages. |
| 12 h 16 | Le résolveur du cluster est forcé, à la main, à donner l'adresse du load balancer pour les deux noms. |
| 12 h 17 | Certificat émis et servi : retour à la normale. La surcharge du résolveur est retirée. |

## Cause

Let's Encrypt ne valide un nom que s'il désigne déjà le cluster : le retour du DNS doit précéder le certificat, et un court intervalle sans certificat valide est inévitable.

Ce qui l'a allongé : avant de soumettre un défi, cert-manager vérifie lui-même que le nom répond, avec le résolveur du cluster. Or les enregistrements de secours, ceux de GitHub Pages, portaient la durée de vie de la zone, une heure, alors que ceux du cluster n'en portent que cinq minutes. Le résolveur du cluster venait de les lire : il les aurait gardés jusqu'à une heure.

## Ce qui a bien fonctionné

- GitHub Pages servait toujours le site, et cette même durée de vie d'une heure y a gardé la plupart des visiteurs pendant l'incident.
- Le message des défis disait exactement ce qui se passait (`wrong status code '404'`).
- Une fois le résolveur corrigé, le certificat est arrivé en vingt-cinq secondes.

## Actions

| Action | Suivi |
| --- | --- |
| Les enregistrements de secours portent la même durée de vie courte que ceux du cluster : un retour se voit en cinq minutes, y compris par le cluster. | Fait : `terraform/dns` |
| Le runbook de reconstruction dit de ramener les visiteurs avant d'attendre le certificat, et pourquoi. | Fait : [reconstruire-la-plateforme](../runbooks/reconstruire-la-plateforme.md), étape 5 |
| Obtenir le certificat avant le retour du DNS demanderait une validation par le DNS plutôt que par HTTP, donc des clés d'OVH dans le cluster. | Non retenu ([ADR 0013](../adr/0013-certificats-par-cert-manager-et-lets-encrypt.md)) |
