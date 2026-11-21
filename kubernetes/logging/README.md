# Journaux

Les journaux des pods sont collectés par Alloy et conservés treize jours par Loki ([ADR 0017](../../docs/adr/0017-journaux-avec-loki-et-alloy.md)). Ils se consultent dans Grafana.

| Composant | Rôle |
| --- | --- |
| Alloy | Suit les journaux de tous les pods par l'API de Kubernetes, comme `kubectl logs`, et les envoie à Loki |
| Loki | Les conserve sur un volume local déclaré dans [`storage`](../storage), et répond aux requêtes de Grafana |

Les deux sont décrits par des manifestes de ce dossier, pas par leurs charts officiels : une image et un pod chacun. Leurs configurations sont dans [`files`](files).

## Consulter

Dans Grafana ([accès](../monitoring/README.md)), vue « Explore », source « Loki ». Chaque ligne porte quatre étiquettes : `namespace`, `pod`, `container` et `app`.

| Besoin | Requête |
| --- | --- |
| Journal des visites | `{namespace="rtgre", container="nginx"}` |
| Erreurs d'une génération | `{namespace="rtgre", container="generator"}` |
| Ce que fait Argo CD | `{namespace="argocd"} \|= "level=error"` |
| Requêtes servies sur 24 heures | `sum(count_over_time({namespace="rtgre", container="nginx"} [24h]))` |

Le tableau de bord « rtgre » affiche les requêtes servies et le nombre de réseaux distincts.

## Conservation

Loki supprime tout journal après treize jours (`loki.retention`). Cette valeur ne doit pas dépasser la limite des journaux de visite, quatorze jours ([ADR 0014](../../docs/adr/0014-journaux-de-visite-sans-adresse-complete.md)) : la raccourcir est libre, l'allonger demande de réviser cet ADR.

## Choix notables

- **Alloy n'a pas accès aux nœuds** : il lit par l'API, avec pour seul droit de lire les pods et leurs journaux. L'espace de noms reste au niveau `restricted`.
- **Un seul Alloy** : deux enverraient chaque ligne en double.
- **Loki sans authentification**, mais fermé : seuls Alloy, Grafana et Prometheus peuvent le joindre.
