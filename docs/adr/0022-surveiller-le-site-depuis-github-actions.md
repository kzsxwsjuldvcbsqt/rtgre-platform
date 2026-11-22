# 0022. Surveiller le site depuis GitHub Actions

- Statut : accepté
- Date : 2026-11-22

## Contexte

Prometheus, sa sonde et Alertmanager tournent sur le cluster qu'ils surveillent, et sur son seul nœud de travail ([ADR 0018](0018-alertes-avec-alertmanager-et-telegram.md)). Si ce nœud tombe, ou tout le cluster, ou la région d'Oracle, le site ne répond plus et aucune alerte ne part.

Il faut une sonde et un canal qui ne dépendent ni du cluster, ni d'Oracle. Les contraintes : aucun compte de plus à ouvrir, aucun secret de plus à garder, et rien à payer.

## Options envisagées

### Un service de surveillance tiers

C'est leur métier, avec des sondes fréquentes et réparties. Chacun demande un compte, et sa configuration vit hors du dépôt.

### Health Checks et alarmes d'Oracle

Des sondes extérieures, décrites en Terraform. Mais l'alarme et son envoi tournent chez Oracle : une panne de la région ou du compte les emporterait avec le site.

### Un workflow planifié de GitHub Actions

Rien à ouvrir : le dépôt y est déjà, et GitHub ne partage rien avec Oracle. La sonde est un fichier du dépôt. Mais un workflow planifié part souvent en retard de plusieurs minutes, et ses exécutions sont comptées si le dépôt devient privé.

## Décision

Un workflow planifié, `Watch`, interroge le site quatre fois par heure, aux minutes 7, 22, 37 et 52 : GitHub retarde ou abandonne volontiers les exécutions planifiées aux minutes rondes.

- **Trois essais espacés de trente secondes** par adresse : une coupure brève n'est pas une panne. Une réponse compte si elle est un 200, en HTTPS, avec un certificat valide.
- **Une panne ouvre une issue « Incident »**, assignée au propriétaire, que GitHub lui signale par courrier. Elle renvoie au runbook, et se ferme d'elle-même au retour du site. Tant qu'elle est ouverte, les sondes suivantes n'ajoutent rien.
- **Aucun secret** : le workflow n'a que le droit d'écrire des issues dans ce dépôt.
- **Une panne se simule** en lançant le workflow à la main avec `simulate_outage` : il sonde un nom qui n'existe pas.

## Conséquences

- Une panne complète est signalée en quinze à trente minutes quand GitHub tient l'horaire. Il ne le garantit pas : dans l'heure et demie qui a suivi la mise en service, aucune exécution planifiée n'est partie. C'est un filet, pas une alerte fine : celles du cluster restent les premières, en cinq minutes.
- Le signalement dépend de GitHub, et des notifications du compte du propriétaire.
- **Si le dépôt devient privé**, chaque exécution compte pour une minute : quatre par heure dépassent les 2 000 minutes gratuites du mois. Passer alors à une sonde par heure, soit environ 750 minutes.
- GitHub suspend les workflows planifiés d'un dépôt public resté soixante jours sans activité. Les mises à jour de Renovate, chaque semaine, l'en gardent.
- La sonde voit ce que voit un visiteur, y compris une panne du DNS ou du load balancer. Elle ne dit pas quel étage est tombé : c'est le rôle du runbook.
