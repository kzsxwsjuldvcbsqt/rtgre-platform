# Métriques

Prometheus collecte les métriques du cluster et les garde quinze jours ([ADR 0015](../../docs/adr/0015-metriques-avec-prometheus-et-son-operateur.md)).

| Composant | Rôle |
| --- | --- |
| Prometheus | Collecte les cibles chaque minute, sur un volume local déclaré dans [`storage`](../storage) |
| Opérateur | Traduit les objets ServiceMonitor et PrometheusRule en configuration de Prometheus |
| kube-state-metrics | Expose l'état des objets du cluster : pods, déploiements, tâches |
| [`node-exporter`](../node-exporter) | Métriques des nœuds, dans sa propre application |

## Ce qui est collecté

| Cible | Ce qu'elle donne |
| --- | --- |
| `kubelet` | Processeur et mémoire de chaque conteneur, volumes |
| `apiserver` | Requêtes à l'API de Kubernetes |
| `coredns` | Résolutions DNS du cluster |
| `kube-state-metrics` | État des objets, dernière réussite des tâches planifiées |
| `prometheus-node-exporter` | Processeur, mémoire, disque et réseau des deux nœuds |

Le planificateur, le gestionnaire de contrôleurs, etcd et kube-proxy ne le sont pas : kubeadm ne les fait écouter que sur la boucle locale du plan de contrôle.

## Ajouter une cible

1. Dans le chart du composant, un ServiceMonitor, et une règle réseau qui laisse entrer les pods de Prometheus (`app.kubernetes.io/name: prometheus`, espace de noms `monitoring`) sur le port des métriques.
2. Ici, une entrée dans `scrape.pods` de [`values.yaml`](values.yaml) : Prometheus ne sort que vers ce qui y figure.

## Ouvrir l'interface

Elle n'est pas exposée. Depuis la racine du dépôt, après avoir ouvert les sessions du Bastion ([se-connecter-a-un-noeud](../../docs/runbooks/se-connecter-a-un-noeud.md)) :

```bash
ssh -t -F ansible/.ssh/bastion.conf -L 8080:127.0.0.1:8080 cp-1 kubectl -n monitoring port-forward svc/monitoring-prometheus 8080:9090
```

Puis ouvrir <http://localhost:8080>. La page « Target health » liste les cibles et leur état. C'est le même port que pour [Argo CD](../../docs/runbooks/acceder-a-argocd.md) : sshd n'en autorise qu'un, donc une interface à la fois. Si le port 8080 est pris sur le poste, changer le premier nombre.

## Choix notables

- **Conservation bornée deux fois** : quinze jours, et 4 Go, sur un volume de 5 Go. Le disque du nœud ne peut pas se remplir de métriques.
- **Toute cible déclarée est candidate**, quel que soit son chart : Prometheus ne filtre pas sur une étiquette de release. Le filtre est la règle réseau.
- **Retirer l'application ne supprime rien** : ses CRD emporteraient les cibles et les règles des autres charts.
