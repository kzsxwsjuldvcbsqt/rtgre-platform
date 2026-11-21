# 0017. Journaux avec Loki et Alloy

- Statut : accepté
- Date : 2026-11-21

## Contexte

Les journaux d'un pod ne se lisent qu'avec `kubectl logs`, en passant par le Bastion, et disparaissent avec lui. Pour diagnostiquer une panne après coup, ou compter les visites du site, il faut les collecter et les garder un temps.

Les contraintes :

- les journaux de visite ne doivent pas dépasser quatorze jours ([ADR 0014](0014-journaux-de-visite-sans-adresse-complete.md)) ;
- aucun espace de noms privilégié de plus : un seul existe, celui de node-exporter ([ADR 0015](0015-metriques-avec-prometheus-et-son-operateur.md)) ;
- les consulter depuis Grafana, qui n'a pas accès à Internet pour télécharger une extension ([ADR 0016](0016-grafana-en-lecture-seule-sans-compte.md)).

## Options envisagées

### Stockage : VictoriaLogs

Très léger, et ses images ne portent aucune vulnérabilité connue. Mais Grafana ne le lit qu'avec une extension à télécharger.

### Stockage : Loki

Grafana le lit sans rien ajouter. Son image ne porte qu'une vulnérabilité HIGH, celle de la bibliothèque standard de Go que tout l'écosystème attend de corriger. Son chart officiel déploie par défaut une passerelle, des caches et un pod de test, à désactiver un par un.

### Collecte : un agent par nœud, qui lit les fichiers

La méthode habituelle : un DaemonSet monte le dossier des journaux du nœud. Monter un dossier de l'hôte exige un espace de noms privilégié.

### Collecte : un agent unique, qui lit par l'API de Kubernetes

Alloy sait suivre les journaux comme le fait `kubectl logs`. Un seul pod, sans accès au disque des nœuds, dans un espace de noms au niveau `restricted`. Chaque ligne passe par l'API : c'est plus coûteux, ce qui ne compte pas avec une trentaine de pods.

## Décision

Loki pour conserver, Alloy pour collecter par l'API, tous deux décrits par des manifestes écrits pour ce cluster plutôt que par leurs charts.

- **Loki en un seul processus**, sur un volume local de 5 Go ([ADR 0011](0011-stocker-sur-des-volumes-locaux-statiques.md)). Sans passerelle ni cache : une image, un pod.
- **Conservation de treize jours**, appliquée par Loki à tous les journaux. Avec son délai de suppression d'une heure, aucun journal de visite ne dépasse la limite de quatorze jours.
- **Alloy lit par l'API de Kubernetes.** Son seul droit dans le cluster : lire les pods et leurs journaux. Il ne peut lire ni un secret ni le disque d'un nœud.
- **Quatre étiquettes** par ligne : espace de noms, pod, conteneur et application. Le contenu des lignes n'est pas modifié.
- **Refus par défaut des entrées et des sorties** : Loki ne reçoit qu'Alloy, Grafana et Prometheus, et ne sort nulle part. Alloy ne joint que l'API et Loki.
- **Mesure** : 120 Mo pour Loki et 133 Mo pour Alloy. Le nœud de travail est à 2,2 Go utilisés sur 5,9.

## Conséquences

- Les journaux de visite existent à deux endroits : sur le nœud, jusqu'au remplacement hebdomadaire du pod, et dans Loki, treize jours. La limite de l'ADR 0014 tient dans les deux.
- La sonde du cluster n'est plus journalisée par nginx : deux requêtes par minute auraient noyé les visites.
- Vérifié à la mise en service : aucune ligne, dans aucun journal collecté, ne contient l'adresse complète du poste qui a servi aux essais.
- Le nombre de « réseaux distincts » affiché dans Grafana approche le nombre de visiteurs, robots compris.
- Alloy lit par l'API : si elle est indisponible, les lignes écrites pendant ce temps sont rattrapées à son retour, tant que le pod qui les a écrites existe encore.
- **Vulnérabilités connues** : une dans chaque image, la même. Suivi dans #73.
- Si la mémoire venait à manquer, Alloy est le premier candidat à alléger : il pèse autant que Loki.
