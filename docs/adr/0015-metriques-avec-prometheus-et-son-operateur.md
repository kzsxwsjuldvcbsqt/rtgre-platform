# 0015. Métriques avec Prometheus et son opérateur

- Statut : accepté
- Date : 2026-11-21

## Contexte

Le cluster sert rtgre.fr, mais rien ne dit s'il va bien : la charge des nœuds, la place sur le disque, les redémarrages de pods ou le succès de la génération horaire ne se lisent qu'en se connectant. Il faut collecter des métriques, les garder quelques jours, et pouvoir s'en servir ensuite pour des tableaux de bord et des alertes.

Les contraintes :

- un seul nœud de travail, de 6 Go, dont 1,4 Go déjà utilisés ;
- des volumes locaux, sur le disque du nœud ([ADR 0011](0011-stocker-sur-des-volumes-locaux-statiques.md)) ;
- le même refus par défaut des entrées et des sorties que pour les autres composants ;
- pas de compte ni de service extérieur à la plateforme.

## Options envisagées

### Un service extérieur

Les métriques partent chez un fournisseur, qui les stocke et les affiche. Rien à faire tourner, sauf un agent. Mais il faut un compte, une clé dans le cluster, et les données quittent la plateforme.

### VictoriaMetrics

Plus léger que Prometheus en mémoire et sur disque, et compatible avec ses requêtes. Ses images ne portent qu'une vulnérabilité HIGH selon Trivy, celle de la bibliothèque standard de Go que tout l'écosystème attend de corriger.

### Prometheus et son opérateur (kube-prometheus-stack)

La référence : presque tous les charts savent déclarer leurs cibles et leurs règles avec les objets de l'opérateur (ServiceMonitor, PrometheusRule). Plus lourd, et ses images portent quelques vulnérabilités de plus.

## Décision

Prometheus et son opérateur, par le chart kube-prometheus-stack, en ne gardant que ce qui sert.

- **Composants** : Prometheus, son opérateur et kube-state-metrics. Grafana et les alertes viennent dans leurs propres étapes.
- **node-exporter à part** : il lit le système hôte, ce qui demande un espace de noms privilégié. Il a donc sa propre application et son propre espace de noms, le seul privilégié du cluster ; celui de Prometheus reste au niveau `restricted`. Sa version (1.13.1) ne porte aucune vulnérabilité connue, contrairement à celle qu'embarque le chart principal.
- **Conservation** : quinze jours et 4 Go au plus, sur un volume local de 5 Go. Une collecte par minute.
- **Sorties filtrées** : Prometheus ne joint que l'API de Kubernetes, kubelet et node-exporter sur les nœuds, et les pods listés dans les valeurs. Une cible ajoutée par un chart n'est pas collectée tant qu'elle n'y figure pas.
- **Pas de Job de certificat** : le certificat du webhook de l'opérateur vient de cert-manager, déjà présent, plutôt que de l'image que le chart utilise par défaut.
- **Ce qui n'est pas collecté** : le planificateur, le gestionnaire de contrôleurs, etcd et kube-proxy. Avec kubeadm, ils n'exposent leurs métriques que sur la boucle locale du plan de contrôle.
- **Mesure**, par Prometheus lui-même : 219 Mo pour l'ensemble, dont 165 Mo pour Prometheus avec 50 000 séries. La mémoire utilisée du nœud de travail passe de 1 350 à 1 694 Mo.

## Conséquences

- Les étapes suivantes s'appuient sur les objets de l'opérateur : une cible est un ServiceMonitor, une alerte une PrometheusRule.
- Exposer les métriques d'un composant demande deux gestes : une règle réseau qui laisse entrer Prometheus chez lui, et une entrée dans les cibles autorisées de Prometheus.
- **Vulnérabilités connues**, selon Trivy, au 21 novembre 2026 :
  - Prometheus 3.16.0 : deux, des dénis de service (bibliothèque standard de Go, `golang.org/x/net`) ;
  - l'opérateur 0.95.2 : une, la même que partout ;
  - kube-state-metrics 2.20.0, sa dernière version, publiée en août : onze, dans la bibliothèque standard de Go, gRPC et `golang.org/x`.

  Aucun de ces pods n'est joignable hors du cluster, et kube-state-metrics n'est lu que par Prometheus. Ces exceptions sont suivies dans #73, qui les fera vérifier par la CI.
- La mémoire de Prometheus grandira avec le nombre de cibles : elle sera remesurée après Grafana, les journaux et les alertes.
- Si la mémoire venait à manquer, VictoriaMetrics lit les mêmes objets et les mêmes requêtes : le changement toucherait ce chart, pas ceux des applications.
