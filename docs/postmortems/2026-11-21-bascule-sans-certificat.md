# 2026-11-21. rtgre.fr sans certificat valide pendant la bascule

- Issue : aucune, l'incident précède le suivi par issue « Incident »
- Durée : de 21 h 33 à 21 h 42, heure de Paris
- Détecté par : la vérification prévue après la bascule

## Résumé

Pendant la bascule de rtgre.fr de GitHub Pages vers le cluster, le site a répondu neuf minutes avec un certificat qui ne couvrait pas son nom. Une minute était prévue. La pull request qui ajoutait le nom au certificat n'a pas pu être fusionnée tout de suite, et son refus n'a pas été vu.

## Impact

Un visiteur dont le résolveur DNS donnait déjà la nouvelle adresse voyait une erreur de certificat dans son navigateur. La zone portait jusque-là une durée de vie d'une heure : la plupart des visiteurs gardaient l'ancienne adresse en cache et ont continué d'être servis par GitHub Pages, sans rien voir. Leur nombre n'a pas été mesuré.

Le courrier du domaine n'a pas été touché, et aucune donnée n'a été perdue.

## Chronologie

| Heure | Événement |
| --- | --- |
| 21 h 33 | Fusion de la pull request du DNS, puis `terraform apply` : la zone désigne le load balancer en moins de dix secondes. |
| 21 h 33 | Fusion de la pull request du certificat lancée dans la foulée. GitHub la refuse : sa branche est en retard sur `main`. Le refus n'est pas lu. |
| Peu après | La vérification du site montre que le certificat ne couvre pas `rtgre.fr`. La pull request est retrouvée ouverte. |
| 21 h 41 | Branche mise à jour, CI repassée, pull request fusionnée. |
| 21 h 42 | Certificat prêt pour `rtgre.fr` et `www.rtgre.fr` : retour à la normale. |

## Cause

Let's Encrypt ne valide un nom que s'il désigne déjà le cluster ([ADR 0013](../adr/0013-certificats-par-cert-manager-et-lets-encrypt.md)) : le nom ne peut entrer dans le certificat qu'après le changement du DNS, et un court intervalle sans certificat est inévitable. Pour le réduire, la pull request du certificat avait été préparée d'avance.

Deux choses l'ont allongé :

- **Une hypothèse fausse.** `main` exige une branche à jour. Dès la fusion de la pull request du DNS, celle du certificat était en retard, donc refusée tant qu'elle n'était pas mise à jour et sa CI repassée.
- **Une erreur masquée.** La sortie de la commande de fusion était filtrée pour n'en garder qu'une ligne. Le refus n'y figurait pas, et la suite s'est déroulée comme si la fusion avait eu lieu.

## Ce qui a bien fonctionné

- GitHub Pages servait toujours le site, et la durée de vie d'une heure de l'ancienne zone a gardé la plupart des visiteurs chez lui pendant l'incident.
- La vérification prévue après la bascule a révélé le problème en quelques minutes.
- Une fois la pull request fusionnée, le certificat est arrivé en moins d'une minute.
- Le retour arrière, joué ensuite pour de vrai, prend neuf secondes.

## Actions

| Action | Suivi |
| --- | --- |
| Le runbook de bascule dit d'ouvrir la pull request du certificat après celle du DNS, ou de vérifier son état avant de compter dessus. | Fait : [basculer-rtgre-fr](../runbooks/basculer-rtgre-fr.md), étape 3 |
| Après toute fusion, lire son résultat et vérifier que la pull request est bien fusionnée avant d'enchaîner. | Fait : c'est la pratique depuis |
| Un certificat invalide est maintenant signalé sans attendre une vérification à la main : la sonde du cluster échoue sur un certificat invalide et déclenche `SiteInjoignable` en cinq minutes, et la sonde extérieure ouvre un incident. | Fait : #86, #91 |
