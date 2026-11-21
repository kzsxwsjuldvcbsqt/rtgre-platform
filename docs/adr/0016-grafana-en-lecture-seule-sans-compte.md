# 0016. Grafana en lecture seule, sans compte

- Statut : accepté
- Date : 2026-11-21

## Contexte

Prometheus collecte les métriques ([ADR 0015](0015-metriques-avec-prometheus-et-son-operateur.md)), mais ses requêtes ne se lisent pas d'un coup d'œil. Grafana les affiche. Par défaut, il vient avec un compte administrateur, une base de données pour ses réglages et des tableaux de bord que l'on modifie à la souris.

Les contraintes :

- aucun secret à gérer si l'on peut s'en passer ;
- tout ce qui tourne se décrit dans le dépôt ;
- l'interface ne doit pas être exposée, comme celle d'Argo CD ([ADR 0010](0010-deployer-en-gitops-avec-argo-cd.md)).

## Options envisagées

### Grafana par défaut

Un compte administrateur, dont le mot de passe est soit écrit dans le dépôt, soit régénéré à chaque rendu du chart, ce qui désynchronise Argo CD en permanence. Les tableaux de bord modifiés dans l'interface vivent dans un volume et ne sont pas dans le dépôt.

### Grafana avec les tableaux de bord du chart

Le chart en fournit une vingtaine, chargés par un conteneur auxiliaire qui surveille l'API de Kubernetes. Ce conteneur est une image de plus, qui porte cinq vulnérabilités HIGH selon Trivy, et il donne à Grafana un jeton de l'API.

### Grafana sans compte, avec ses tableaux de bord dans le dépôt

Aucun compte : Grafana est en lecture seule pour quiconque l'atteint, et l'atteindre demande de passer le Bastion. Les tableaux de bord sont des fichiers du dépôt, montés tels quels.

## Décision

Grafana sans compte, en lecture seule, avec deux tableaux de bord écrits pour ce cluster.

- **Aucun compte** : pas d'administrateur créé au démarrage, pas de formulaire de connexion, accès anonyme en lecture. Le contrôle d'accès est celui du Bastion : une authentification Oracle, une clé SSH, puis le droit de rediriger un port.
- **Tout vient du dépôt** : la source de données et les tableaux de bord sont montés depuis des ConfigMap. Rien ne se modifie dans l'interface, et Grafana n'a pas de volume.
- **Deux tableaux de bord**, « Plateforme » et « rtgre », générés par `scripts/grafana-dashboards.py`. Chaque requête a été vérifiée contre Prometheus avant d'y entrer.
- **Sans conteneur auxiliaire ni jeton de l'API** : Grafana ne joint que Prometheus, et le DNS pour le trouver.
- **Branche 13.1** : la version 13.1.10, encore maintenue, porte six vulnérabilités HIGH selon Trivy, contre trente-cinq pour la 13.3.1 que propose le chart.
- **Mesure** : 239 Mo de mémoire pendant l'affichage des tableaux de bord. C'est le composant le plus lourd de la métrologie, devant Prometheus.

## Conséquences

- Modifier un tableau de bord, c'est modifier le script, le relancer et ouvrir une pull request : plus lent qu'à la souris, mais relu et versionné.
- Pas d'exploration libre enregistrée : une requête ponctuelle se fait dans l'interface de Prometheus ou dans la vue « Explore », sans pouvoir la sauvegarder.
- **Vulnérabilités connues** : six, dans la bibliothèque standard de Go, `golang.org/x/net` et un composant de traçage que cette installation n'utilise pas. Grafana n'est joignable que par le Bastion. Suivi dans #73.
- Renovate proposera les branches suivantes de Grafana : une montée mineure attend une approbation, le temps de comparer leurs vulnérabilités.
- Si plusieurs personnes devaient un jour y accéder avec des droits différents, il faudrait des comptes, donc un secret : cette décision serait à revoir.
