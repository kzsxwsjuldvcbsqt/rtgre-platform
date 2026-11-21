# Recevoir les alertes

Prometheus évalue les règles d'alerte chaque minute, et Alertmanager envoie celles qui se déclenchent sur Telegram ([ADR 0018](../adr/0018-alertes-avec-alertmanager-et-telegram.md)). Chaque message porte un lien « Que faire » vers le runbook de l'alerte. Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

## Relier le bot Telegram

À faire une fois, puis après toute reconstruction du cluster. Le jeton du bot ne va ni dans le dépôt, ni dans une commande : seulement dans un fichier du poste, puis dans un Secret du cluster.

1. Dans Telegram, écrire à [@BotFather](https://t.me/BotFather) : `/newbot`, puis un nom et un identifiant qui finit par `bot`. Il répond avec le jeton.
2. Créer le fichier du jeton, fermé aux autres comptes, et y coller le jeton avec un éditeur :

```bash
install -D -m 600 /dev/null ~/.config/rtgre-platform/telegram-bot-token
```

3. Écrire un message quelconque au nouveau bot : c'est cette discussion qui recevra les alertes.
4. Depuis la racine du dépôt :

```bash
scripts/alertmanager-telegram.sh
```

Le script vérifie le jeton, envoie un message de bienvenue, crée le Secret `alertmanager-telegram`, puis envoie une alerte d'essai. Elle arrive en moins d'une minute, et son message « Résolu » cinq minutes après.

Le fichier du poste peut ensuite être supprimé : BotFather redonne le jeton à la demande (`/token`).

## Envoyer une alerte d'essai

```bash
scripts/alertmanager-telegram.sh --test
```

## Voir les alertes en cours

Dans Grafana, le tableau « Plateforme » les compte ([ouvrir Grafana](../../kubernetes/monitoring/README.md)). Leur détail :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n monitoring exec alertmanager-monitoring-alertmanager-0 -c alertmanager -- amtool alert query --alertmanager.url http://127.0.0.1:9093
```

## Faire taire une alerte

Pendant une intervention prévue, pour quatre heures :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n monitoring exec alertmanager-monitoring-alertmanager-0 -c alertmanager -- amtool silence add alertname=PodEnBoucle --duration 4h --comment 'Intervention en cours' --alertmanager.url http://127.0.0.1:9093"
```

La commande affiche l'identifiant du silence. Pour le lever avant son terme, la même commande avec `amtool silence expire <identifiant>`. Un silence disparaît aussi si le pod d'Alertmanager redémarre : il n'a pas de volume.

## Aucun message n'arrive

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n monitoring logs alertmanager-monitoring-alertmanager-0 -c alertmanager --since 1h
```

| Journal | Cause | Que faire |
| --- | --- | --- |
| `could not read /etc/alertmanager/telegram/bot-token` | Le Secret n'existe pas, par exemple après une reconstruction du cluster. | Relier le bot. |
| `Unauthorized` | Le jeton a été révoqué. | En demander un nouveau à BotFather, puis relier le bot. |
| `chat not found` | Le bot n'a jamais reçu de message dans cette discussion. | Lui écrire, puis relier le bot. |
| `context deadline exceeded` | Telegram est injoignable, ou son nom a changé. | Vérifier `alerting.telegram.host` dans `kubernetes/monitoring/values.yaml` : c'est le seul nom qu'Alertmanager peut joindre. |
| Rien | Aucune alerte n'est partie de Prometheus. | Envoyer une alerte d'essai. |

## Changer de jeton

Dans BotFather, `/revoke` invalide l'ancien jeton et en donne un nouveau. Le placer dans le fichier du poste, puis relancer `scripts/alertmanager-telegram.sh`.

## Ce que les alertes ne voient pas

Prometheus et Alertmanager tournent sur le cluster qu'ils surveillent. Si le nœud de travail tombe, ou tout le cluster, aucune alerte ne part.
