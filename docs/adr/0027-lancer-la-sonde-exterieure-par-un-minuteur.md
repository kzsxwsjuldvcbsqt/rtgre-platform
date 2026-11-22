# 0027. Lancer la sonde extérieure par un minuteur

- Statut : accepté
- Date : 2026-11-22

## Contexte

Le workflow `Watch` sonde le site depuis GitHub, quatre fois par heure sur le papier ([ADR 0022](0022-surveiller-le-site-depuis-github-actions.md)). GitHub ne tient pas l'horaire d'un workflow planifié : la sonde n'est presque jamais partie d'elle-même. Les alarmes d'Oracle ont pris le rôle de premier signal extérieur ([ADR 0024](0024-surveiller-le-load-balancer-par-une-alarme-d-oracle.md)), mais elles tournent chez Oracle, comme le site. `Watch` est le seul regard qui vienne d'ailleurs : il doit partir pour de bon.

Le dépôt rtgre a le même problème pour sa mise à jour horaire, et l'a résolu par un minuteur.

## Options envisagées

### Garder l'horaire de GitHub

Rien à faire. Mais une sonde qui ne part pas ne surveille rien.

### Un service extérieur qui lance le workflow

Fiable, mais un compte et un jeton de plus, hors du dépôt.

### Un workflow qui attend dans le workflow

Une étape `sleep` de quinze minutes occupe une machine tout ce temps : gratuit tant que le dépôt est public, hors de prix s'il devenait privé.

### Un minuteur par le délai d'un environnement

Un environnement GitHub peut retenir un travail un temps donné avant de lui donner une machine. Un workflow qui passe par cet environnement, puis se relance, forme une horloge qui ne consomme rien pendant l'attente. C'est le minuteur du dépôt rtgre.

## Décision

Le workflow `Watch timer` passe par l'environnement `watch-timer`, dont le délai est de quinze minutes, puis se relance et lance `Watch`. `Watch` n'a plus d'horaire.

- **Un horaire de secours**, toutes les quatre heures, redémarre la chaîne si elle s'est interrompue. Il vérifie d'abord qu'aucun minuteur n'attend déjà : il n'y a jamais deux chaînes.
- **La sonde part même si le minuteur suivant n'a pas pu être relancé.**
- **Aucun secret** : le minuteur n'a que le droit de lancer des workflows de ce dépôt.
- **L'environnement n'accepte que `main`**.
- **Sans délai, pas de minuteur** : le workflow lit le délai de l'environnement avant de s'y engager, et s'arrête s'il est nul ou si l'environnement manque. Sans cela, il se relancerait sans fin et sans attendre.

## Conséquences

- Les deux dépôts ont le même mécanisme, avec les mêmes noms d'étapes.
- **Le délai de l'environnement ne vit pas dans le dépôt** : c'est un réglage de GitHub (« Settings », « Environments », `watch-timer`, « Wait timer »). Le README dit comment le recréer.
- Chaque attente apparaît comme un déploiement de l'environnement `watch-timer` : quatre par heure dans l'historique des déploiements du dépôt.
- Une chaîne lancée à la main alors qu'une autre attend en crée une seconde : seul l'horaire de secours vérifie. La sonde n'en souffre pas, une seule s'exécute à la fois.
- Si la chaîne casse, la sonde manque jusqu'au prochain horaire de secours, quatre heures au plus, si GitHub le lance. Les alarmes d'Oracle et les alertes du cluster ne dépendent pas d'elle.
- **Si le dépôt devient privé**, le minuteur et la sonde comptent chacun pour une minute par exécution : passer le délai à une heure, comme le prévoyait l'ADR 0022.
