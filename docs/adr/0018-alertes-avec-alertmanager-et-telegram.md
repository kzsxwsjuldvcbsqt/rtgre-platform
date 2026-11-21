# 0018. Alertes avec Alertmanager et Telegram

- Statut : accepté
- Date : 2026-11-21

## Contexte

Les tableaux de bord ne servent que si quelqu'un les regarde. Une panne qui touche les visiteurs, ou qui les touchera bientôt, doit arriver d'elle-même au propriétaire, seul exploitant de la plateforme.

Les contraintes :

- une alerte reçue doit dire quoi faire : chacune renvoie à un runbook ;
- peu d'alertes, toutes utiles : une alerte ignorée en cache dix ;
- le secret du canal de réception reste hors du dépôt ;
- Grafana est en lecture seule et sans compte ([ADR 0016](0016-grafana-en-lecture-seule-sans-compte.md)) : il ne peut pas porter les alertes.

## Options envisagées

### Règles : celles du chart kube-prometheus-stack

Plus de cent règles, maintenues par la communauté. Beaucoup visent des composants que ce cluster n'expose pas à Prometheus (etcd, planificateur, gestionnaire de contrôleurs) et ne se déclencheraient jamais. Aucune ne connaît le site, sa génération ni ses journaux, et leurs runbooks sont génériques.

### Règles : écrites pour ce cluster

Une douzaine, chacune liée à une panne identifiée et à un runbook du dépôt. Elles sont à maintenir, et à tester.

### Canal : courrier électronique

Aucun secret côté destinataire, mais il faut un serveur d'envoi et son mot de passe, et un courrier se lit tard.

### Canal : Discord

Une adresse de webhook suffit. Elle vaut mot de passe, et demande un serveur Discord.

### Canal : Telegram

Un bot et son jeton. Alertmanager le gère sans extension, le message arrive en notification sur le téléphone, et le propriétaire l'a choisi.

## Décision

Alertmanager, douze règles écrites pour ce cluster, et Telegram.

- **Les règles sont un fichier de Prometheus**, `kubernetes/monitoring/files/alerts.yaml`. `promtool` les vérifie et joue leurs tests dans la CI : chaque règle a un cas où elle se déclenche et un cas où elle se tait.
- **Chaque règle cite un runbook.** Le chart refuse de se rendre sans lui, et la CI vérifie que le fichier existe. Le message Telegram en donne le lien.
- **Deux niveaux** : `critical` quand les visiteurs sont touchés maintenant, rappelé toutes les deux heures ; `warning` quand ils le seront si rien n'est fait, rappelé chaque jour.
- **Le jeton du bot est dans un Secret créé hors du dépôt**, par `scripts/alertmanager-telegram.sh`, à partir d'un fichier du poste. Le volume est facultatif : sans le Secret, Alertmanager tourne et consigne qu'il ne peut pas envoyer.
- **Alertmanager ne peut joindre que Telegram**, et ne reçoit que Prometheus. Il n'a aucun jeton de l'API de Kubernetes.
- **Mesure** : 29 Mo.

## Conséquences

- **Les alertes partent du cluster qu'elles surveillent.** Si le nœud de travail tombe, ou tout le cluster, rien ne part. Une surveillance extérieure reste à ajouter : #91.
- La sonde du site part aussi du cluster : elle ne voit pas une panne du réseau entre les visiteurs et Oracle.
- Après une reconstruction du cluster, le bot est à relier de nouveau ([runbook](../runbooks/recevoir-les-alertes.md)).
- Les silences ne survivent pas à un redémarrage d'Alertmanager, qui n'a pas de volume : ils ne servent qu'à une intervention en cours.
- Telegram voit le contenu des alertes : des noms de pods, de nœuds et de certificats, jamais une donnée de visiteur.
- Ajouter une alerte demande une règle, son test et son runbook.
- **Vulnérabilités connues** : deux dans l'image d'Alertmanager. Suivi dans #73.
