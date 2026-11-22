# 0025. Mesurer l'audience avec Umami

- Statut : accepté
- Date : 2026-11-22

## Contexte

Le propriétaire veut savoir comment le site est utilisé, sur la durée : visites et visiteurs par jour, pages vues, provenance, pays, système et appareil, horaires, temps passé, éléments cliqués.

Grafana n'y répond pas. Ses panneaux comptent des requêtes et des réseaux distincts sur vingt-quatre heures, robots compris, avec treize jours d'historique au plus ([ADR 0017](0017-journaux-avec-loki-et-alloy.md)).

Les contraintes :

- aucun cookie, et aucun suivi d'un visiteur d'un site à l'autre ;
- les données restent sur la plateforme ;
- le nœud de travail a 6 Go de mémoire, dont 2,3 sont occupés ;
- le site interdit toute requête réseau par sa politique de sécurité, que cette mesure ne doit ouvrir qu'au site lui-même ;
- les journaux du serveur web ne gardent que le réseau du visiteur ([ADR 0014](0014-journaux-de-visite-sans-adresse-complete.md)).

## Options envisagées

### Tirer davantage des journaux

Rien à déployer. Mais les journaux ne connaissent ni le temps passé, ni les clics, ni l'appareil de façon fiable, et ne dépassent pas quatorze jours.

### GoatCounter

Un seul binaire et une base SQLite, très léger. Il compte les pages, les provenances et les navigateurs, mais suit mal le temps passé et les clics.

### Plausible, Matomo

Complets. Plausible demande deux bases, dont ClickHouse ; Matomo, PHP et MySQL. Trop lourds pour ce nœud.

### Umami

Une application et une base PostgreSQL. Sans cookie, avec un tableau de bord prêt : visites, visiteurs, pages, provenance, pays, système, appareil, durée, et des événements pour les clics.

## Décision

Umami, avec sa base PostgreSQL sur un volume local, déployés par Argo CD.

- **Seule la collecte est exposée, sous le nom du site.** La passerelle n'ouvre que deux chemins de `rtgre.fr` vers Umami : le script et le point d'envoi. La politique de sécurité du site ne s'ouvre ainsi qu'au site lui-même.
- **Le tableau de bord n'a aucune route.** Il s'ouvre par le Bastion, comme Grafana et Argo CD.
- **Umami lit l'adresse complète du visiteur à l'arrivée**, pour en déduire un pays, une région et une ville approchée, et pour reconnaître un même visiteur dans la journée. Il n'enregistre pas l'adresse. Les journaux du serveur web, eux, ne changent pas.
- **Aucune sortie vers Internet** : Umami ne joint que sa base. La base de localisation est dans son image.
- **Les secrets restent hors du dépôt** : `scripts/umami-secret.sh` tire au hasard le mot de passe de la base et la clé des sessions.

## Conséquences

- **La promesse faite aux visiteurs change.** L'ADR 0014 reste vrai pour les journaux, mais une adresse complète est désormais lue, sans être gardée, pour la mesure d'audience. Le texte d'information du site doit le dire avant que le script n'y soit ajouté, dans le dépôt rtgre.
- La mesure d'audience sans consentement est encadrée : statistiques anonymes, pas de suivi entre sites, visiteurs informés. Le respect de ce cadre relève du propriétaire.
- **La base vit sur un volume local** : elle disparaît avec le nœud. Sa sauvegarde hors du cluster est suivie dans #115.
- Un bloqueur de publicité peut empêcher le script de se charger : les chiffres sont un minimum.
- Quand le site est servi par GitHub Pages, en secours, rien n'est mesuré : les deux chemins n'y existent pas.
- Umami crée à son premier démarrage un compte d'administration au mot de passe connu. Le tableau de bord n'est pas exposé, mais ce mot de passe est à changer à la première connexion.
- **Vulnérabilités connues** : cinq dans l'image d'Umami et une dans celle de PostgreSQL, exceptions datées dans `.trivyignore.yaml`. L'outil `gosu` des images officielles, qui ne s'exécute pas sans root, est écarté de l'analyse.
