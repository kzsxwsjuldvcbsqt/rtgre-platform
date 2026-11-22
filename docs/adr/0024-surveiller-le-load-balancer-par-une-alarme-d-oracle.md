# 0024. Surveiller le load balancer par une alarme d'Oracle

- Statut : accepté
- Date : 2026-11-22

## Contexte

L'[ADR 0022](0022-surveiller-le-site-depuis-github-actions.md) confiait la surveillance extérieure à un workflow planifié de GitHub Actions. À l'usage, GitHub ne tient pas l'horaire : dans les trois heures qui ont suivi la mise en service, aucune de la douzaine d'exécutions planifiées n'est partie, et le dépôt du site, planifié toutes les six heures, voit les siennes partir avec quarante minutes à une heure de retard.

Il faut donc un signal extérieur au cluster qui ne dépende pas de cet horaire, toujours sans compte ni secret de plus, et sans rien payer.

## Options envisagées

### Un service de surveillance tiers

Fiable, mais un compte de plus, hors du dépôt.

### Health Checks d'Oracle

Des sondes HTTP depuis plusieurs points du monde. Le service n'est pas dans la liste des ressources toujours gratuites, et son prix n'a pas pu être vérifié.

### Une alarme sur la sonde du load balancer

Le load balancer sonde déjà le nœud de travail, toutes les dix secondes, et publie le nombre d'instances saines. Une alarme d'Oracle peut prévenir quand il tombe à zéro. Les alarmes et mille courriers de notification par mois sont dans l'offre gratuite.

## Décision

Deux alarmes d'Oracle sur la sonde du load balancer, déclarées avec lui dans Terraform. Le workflow `Watch` reste, comme second filet quand GitHub le lance.

- **`no-healthy-backend`** : plus aucune instance saine derrière le load balancer.
- **`no-backend`** : la métrique manque, ce qui arrive quand il n'y a plus d'instance du tout.
- **Cinq minutes d'attente** avant de prévenir, comme l'alerte du cluster : un nœud qui redémarre en manque trois.
- **Par courrier**, par le service de notifications d'Oracle, avec le lien du runbook. Le sujet et son abonné sont créés par le bootstrap, l'adresse hors du dépôt.

## Conséquences

- Vérifié sur l'historique de la métrique : elle est tombée à zéro pendant les trois minutes du redémarrage du nœud de travail, et a manqué pendant la reconstruction.
- **Ce signal couvre ce que les alertes du cluster ne voient pas** : le nœud de travail arrêté, le cluster entier tombé, la passerelle hors service.
- Il ne voit pas une page d'erreur servie par une passerelle en vie : la sonde est une connexion TCP. Ce cas-là, le cluster est debout et ses propres alertes partent.
- **Il dépend d'Oracle.** Une panne de toute la région emporterait le site et l'alarme. Seul le workflow `Watch` regarde depuis ailleurs, quand GitHub veut bien le lancer.
- Le destinataire doit valider une fois le courrier de confirmation d'Oracle : sans cela, rien ne lui est envoyé.
- La CI reçoit le droit de gérer les alarmes du compartiment et de publier dans le sujet, pas de le modifier.
