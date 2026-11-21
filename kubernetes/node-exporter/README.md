# node-exporter

Expose les métriques de chaque nœud à Prometheus : processeur, mémoire, disque, réseau ([ADR 0015](../../docs/adr/0015-metriques-avec-prometheus-et-son-operateur.md)). Un pod par nœud, plan de contrôle compris.

Il lit `/proc`, `/sys` et la racine du nœud, et utilise le réseau de l'hôte. C'est pourquoi il a sa propre application et son propre espace de noms, le seul du cluster au niveau Pod Security `privileged`. Tout le reste de la métrologie reste au niveau `restricted`.

Sur les nœuds, son port 9100 n'est joignable que du réseau virtuel et des pods : le pare-feu des nœuds et les groupes de sécurité d'Oracle le ferment à Internet.
