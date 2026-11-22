# Diagnostiquer un pod

Alertes `PodEnBoucle` (des redémarrages soutenus pendant vingt minutes) et `CibleInjoignable` (Prometheus ne joint plus une cible depuis un quart d'heure). Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

## Un pod redémarre en boucle

L'alerte donne l'espace de noms, le pod et le conteneur.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n <espace> describe pod <pod>
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n <espace> logs <pod> -c <conteneur> --previous
```

`--previous` lit le journal du conteneur qui vient de s'arrêter. Dans Grafana, Loki garde aussi ceux des redémarrages plus anciens : `{namespace="<espace>", pod="<pod>"}`.

| `Last State` dans `describe` | Cause | Que faire |
| --- | --- | --- |
| `OOMKilled` | Le conteneur a dépassé sa limite de mémoire. | Mesurer son besoin dans Grafana, puis relever la limite dans les valeurs de son chart. |
| `Error`, avec un message dans le journal | Configuration invalide, ou dépendance injoignable. | Lire le journal. Si le pod a changé récemment, annuler la pull request en cause. |
| `Completed`, puis redémarrage | La sonde de vie échoue. | Lire les événements à la fin de `describe`. |
| `ImagePullBackOff` dans l'état courant | L'image n'existe pas, ou le registre ne répond pas. | Vérifier l'étiquette et l'empreinte dans les valeurs du chart. |

Un message `dial tcp … i/o timeout` vers un autre pod ou vers Internet désigne presque toujours une règle réseau : chaque espace de noms refuse tout par défaut. Pour voir ce qui est refusé, interroger l'agent Cilium du nœud où tourne le pod :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n kube-system get pods -l k8s-app=cilium -o wide
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n kube-system exec <pod cilium du nœud> -c cilium-agent -- cilium-dbg monitor --type drop
```

Chaque ligne donne la source, la destination et le port refusés.

## Un pod n'est pas créé

Dans l'espace de noms du site, un Job ou un Deployment peut exister sans pod : l'admission l'a refusé. Le message est dans les événements, et le [README de `kubernetes/kyverno`](../../kubernetes/kyverno/README.md) dit quoi faire de chacun.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre get events --field-selector type=Warning --sort-by=.lastTimestamp
```

## Prometheus ne joint plus une cible

L'alerte donne la tâche de collecte (`job`) et l'adresse de la cible. La page « Target health » de Prometheus affiche l'erreur exacte ([ouvrir Prometheus](../../kubernetes/monitoring/README.md)).

| Erreur | Cause | Que faire |
| --- | --- | --- |
| `connection refused` | Le pod de la cible est arrêté ou redémarre. | Voir ci-dessus. |
| `context deadline exceeded` | Une règle réseau refuse Prometheus. | La cible doit figurer dans `scrape.pods` de `kubernetes/monitoring/values.yaml`, et son chart doit laisser entrer Prometheus. |
| Toutes les cibles d'un même nœud | Le nœud est arrêté ou injoignable. | `kubectl get nodes`, puis la console d'Oracle. |
