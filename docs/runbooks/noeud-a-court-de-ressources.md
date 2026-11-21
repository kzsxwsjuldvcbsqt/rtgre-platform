# Un nœud manque de disque ou de mémoire

Alertes `NoeudDisquePresquePlein` (moins de 25 % de place) et `NoeudMemoirePresquePleine` (moins de 10 % de mémoire disponible), tenues un quart d'heure. L'alerte nomme le nœud ; les exemples prennent `wk-1`. Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

## Le disque

Le disque de démarrage porte le système, les images des conteneurs, leurs journaux et les volumes locaux ([ADR 0011](../adr/0011-stocker-sur-des-volumes-locaux-statiques.md)).

```bash
ssh -F ansible/.ssh/bastion.conf wk-1 df -h /
ssh -F ansible/.ssh/bastion.conf wk-1 "sudo du -xh --max-depth=1 /var/lib /var/log | sort -h | tail -n 12"
```

| Dossier qui grossit | Cause | Que faire |
| --- | --- | --- |
| `/var/lib/containerd` | Images inutilisées, gardées après les mises à jour. | `sudo crictl rmi --prune` |
| `/var/log/journal` | Journal du système. | `sudo journalctl --vacuum-time=7d` |
| `/var/lib/kubernetes-local-volumes/prometheus` | Ne devrait pas dépasser 4 Go. | Vérifier `retentionSize` dans `kubernetes/monitoring/values.yaml`. |
| `/var/lib/kubernetes-local-volumes/loki` | Un pod écrit beaucoup de journaux, ou la conservation est en panne. | Trouver le pod bavard dans Grafana ; voir [retablir-la-conservation-des-journaux](retablir-la-conservation-des-journaux.md). Réduire `loki.retention` si le volume normal a grandi. |
| `/var/log/pods` | Un pod écrit beaucoup de journaux. | Le kubelet les fait tourner : corriger le pod. |

Quand il reste moins de 15 % de place, le kubelet déclare le nœud sous pression : il supprime les images inutilisées, puis expulse des pods. L'alerte part avant, pour laisser le temps d'agir.

## La mémoire

```bash
ssh -F ansible/.ssh/bastion.conf wk-1 free -m
ssh -F ansible/.ssh/bastion.conf wk-1 "ps -eo rss,comm --sort=-rss | head -n 12"
```

Dans Grafana, le panneau « Mémoire, par espace de noms » du tableau « Plateforme » montre qui a grossi, et depuis quand.

| Constat | Que faire |
| --- | --- |
| Un pod grossit sans s'arrêter | Fuite : le redémarrer (`kubectl -n <espace> delete pod <pod>`), puis chercher la cause. Sa limite de mémoire finira par le faire redémarrer seul. |
| Tous les pods sont à leur niveau habituel | Le nœud est trop petit pour ce qu'il porte, et les deux nœuds occupent déjà toute la mémoire gratuite d'Oracle : il faut alléger. Alloy est le premier candidat, il pèse autant que Loki ([ADR 0017](../adr/0017-journaux-avec-loki-et-alloy.md)). |

Chaque conteneur a une limite de mémoire : un seul ne peut pas saturer le nœud. C'est leur somme qu'il faut surveiller en ajoutant une application.
