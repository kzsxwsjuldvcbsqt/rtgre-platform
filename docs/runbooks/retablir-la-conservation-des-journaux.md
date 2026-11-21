# Rétablir la conservation des journaux

Les journaux de visite ne sont pas gardés plus de quatorze jours ([ADR 0014](../adr/0014-journaux-de-visite-sans-adresse-complete.md)). Deux mécanismes tiennent cette limite, et chacun a son alerte. Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

| Alerte | Mécanisme en panne | Marge avant de dépasser la limite |
| --- | --- | --- |
| `JournauxDeVisiteTropAnciens` | Le remplacement du serveur web, chaque lundi à 4 h 30 | Six jours |
| `ConservationDeLokiEnPanne` | La suppression par Loki, après treize jours | Un jour, si les plus vieux journaux ont déjà treize jours |

## Le serveur web n'a pas été remplacé

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre get cronjob rtgre-log-retention
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre get jobs,pods
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre logs job/<nom du job>
```

Relancer la tâche à la main :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre create job --from=cronjob/rtgre-log-retention conservation-manuelle
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre wait job/conservation-manuelle --for=condition=complete --timeout=120s
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre delete job conservation-manuelle
```

Si elle échoue encore, remplacer le pod directement : les journaux partent avec lui, et la limite est tenue pendant que la tâche est corrigée.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre rollout restart deployment/rtgre-web
```

| Journal de la tâche | Cause | Que faire |
| --- | --- | --- |
| `HTTP Error 403: Forbidden` | Le compte de service de la tâche a perdu son droit sur le déploiement. | Comparer le Role de `kubernetes/rtgre/templates/log-retention.yaml` avec le cluster. |
| `timed out` | La règle réseau ne laisse plus la tâche joindre l'API de Kubernetes. | Lire les règles de `kubernetes/rtgre/templates/networkpolicies.yaml`. |
| Aucun Job depuis lundi | Le CronJob est suspendu, ou le nœud était arrêté à 4 h 30. | Relancer à la main. |

## Loki ne supprime plus

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n logging logs loki-0 --since 6h | grep -i -E 'retention|compactor' | tail -n 20"
ssh -F ansible/.ssh/bastion.conf wk-1 df -h /var/lib/kubernetes-local-volumes/loki
```

| Constat | Que faire |
| --- | --- |
| Loki ne tourne pas | [diagnostiquer-un-pod](diagnostiquer-un-pod.md). Le compacteur passe toutes les dix minutes : l'alerte cesse peu après son retour. |
| Le disque est plein | [noeud-a-court-de-ressources](noeud-a-court-de-ressources.md) : Loki ne peut plus écrire, donc plus supprimer. |
| Une erreur du compacteur revient à chaque passage | Redémarrer Loki : `kubectl -n logging delete pod loki-0`. |

En dernier recours, si la limite approche : vider le volume, puis redémarrer Loki, qui repart comme à son premier lancement. Tous les journaux sont perdus, ce qui vaut mieux que de les garder trop longtemps. Cette procédure n'a encore jamais été jouée.

```bash
ssh -F ansible/.ssh/bastion.conf wk-1 "sudo find /var/lib/kubernetes-local-volumes/loki -mindepth 1 -delete"
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n logging delete pod loki-0
```
