# Rétablir une application Argo CD

Alertes `ApplicationDesynchronisee` (l'application ne correspond plus au dépôt, depuis trente minutes) et `ApplicationDegradee` (ses objets ne sont pas sains, depuis une heure et demie). Argo CD corrige seul un écart : une alerte signifie qu'il n'y arrive pas. Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

## Voir l'état

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get applications.argoproj.io
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n argocd get applications.argoproj.io <nom> -o jsonpath='{.status.operationState.message}{\"\n\"}{range .status.conditions[*]}{.type}: {.message}{\"\n\"}{end}'"
```

Le détail, objet par objet, se lit mieux dans l'interface ([acceder-a-argocd](acceder-a-argocd.md)).

## L'application ne correspond plus au dépôt

| Constat | Cause | Que faire |
| --- | --- | --- |
| La colonne de révision ne vaut pas `main`, ou `root` est désynchronisée | Une branche est à l'essai sur le cluster. | L'essai fini, depuis `main` à jour : `scripts/argocd-try-branch.sh` |
| Le message cite un objet refusé par l'API | Un manifeste du dépôt est invalide pour ce cluster. | Corriger par une pull request. Le workflow Kubernetes aurait dû l'arrêter : compléter sa validation. |
| `ComparisonError`, dépôt injoignable | La clé de déploiement a été retirée, ou GitHub ne répond pas. | [renouveler-la-cle-de-deploiement-d-argocd](renouveler-la-cle-de-deploiement-d-argocd.md). |
| Un champ change sans cesse entre deux valeurs | Un contrôleur du cluster modifie un objet que le dépôt décrit. | Retirer le champ du dépôt, ou le faire ignorer par l'application. |

Pour forcer une nouvelle comparaison sans attendre :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd annotate applications.argoproj.io <nom> argocd.argoproj.io/refresh=hard --overwrite
```

## L'application n'est pas saine

L'état vient d'un de ses objets : un pod qui ne démarre pas, un volume en attente, un certificat non prêt. Pour l'application `rtgre`, c'est le plus souvent une génération en échec : une seule ne déclenche pas l'alerte, voir [suivre-la-generation-du-site](suivre-la-generation-du-site.md).

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n argocd get applications.argoproj.io <nom> -o jsonpath='{range .status.resources[?(@.health.status!=\"Healthy\")]}{.kind}/{.name}: {.health.status} {.health.message}{\"\n\"}{end}'"
```

Puis, selon l'objet : [diagnostiquer-un-pod](diagnostiquer-un-pod.md), [suivre-les-certificats](suivre-les-certificats.md), ou le [README de `kubernetes/storage`](../../kubernetes/storage/README.md) pour un volume.
