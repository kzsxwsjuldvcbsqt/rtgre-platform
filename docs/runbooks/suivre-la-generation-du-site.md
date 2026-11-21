# Suivre la génération du site

Le site est généré chaque heure, à la septième minute, par le CronJob `rtgre-generator` ([README de `kubernetes/rtgre`](../../kubernetes/rtgre/README.md)). Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

## Voir l'état

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre get cronjob,jobs,pods
```

- `LAST SCHEDULE` du CronJob date de moins d'une heure.
- Le dernier Job est `Complete`. Le cluster garde la dernière réussite et les trois derniers échecs.
- Le pod `rtgre-web` est `Running` et prêt (`1/1`).

## Lire une génération

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre logs job/<nom du job>
```

Une génération réussie n'écrit rien et dure une vingtaine de secondes.

## Lancer une génération sans attendre

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre create job --from=cronjob/rtgre-generator generation-manuelle
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre wait job/generation-manuelle --for=condition=complete --timeout=600s
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre delete job generation-manuelle
```

## Une génération échoue

| Journal du Job | Cause | Que faire |
| --- | --- | --- |
| `Failed to fetch ADE calendar…` | ADE ne répond pas : le générateur a réessayé puis abandonné. | Rien : le site publié reste en place, l'heure suivante réessaie. Le site prévient lui-même ses visiteurs après douze heures sans mise à jour. |
| `Another build is publishing…` | Une autre génération tenait le volume. | Rien, sauf si l'erreur revient chaque heure : chercher alors un Job bloqué. |
| Autre erreur Python | La réponse d'ADE ou la configuration du site a changé. | Corriger dans le dépôt rtgre. Le site publié reste en place en attendant. |

Si le nom d'ADE change, il se corrige à deux endroits : la configuration du site, dans le dépôt rtgre, et `generator.adeHost`, dans `kubernetes/rtgre/values.yaml`. Sinon la politique réseau bloque le nouveau nom.

## Le site ne répond plus

1. Le pod `rtgre-web` n'est pas prêt : `kubectl -n rtgre describe pod -l app.kubernetes.io/component=web`. Bloqué à l'initialisation, c'est que le volume est vide et qu'ADE ne répond pas : il réessaie de lui-même.
2. Le volume reste en attente (`Pending`) après une suppression de l'espace de noms : le libérer, voir le [README de `kubernetes/storage`](../../kubernetes/storage/README.md).
