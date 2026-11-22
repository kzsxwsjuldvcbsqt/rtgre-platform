# Recevoir les alertes

Prometheus évalue les règles d'alerte chaque minute, et Alertmanager envoie celles qui se déclenchent par courrier ([ADR 0021](../adr/0021-envoyer-les-alertes-par-courrier.md)). Chaque message porte un lien « Que faire » vers le runbook de l'alerte. Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

Le courrier part de `cluster@alertes.rtgre.fr`, par le service Email Delivery d'Oracle. L'expéditeur, sa signature et son identifiant SMTP sont créés par [`terraform/bootstrap`](../../terraform/bootstrap), et les enregistrements DNS du sous-domaine par [`terraform/dns`](../../terraform/dns).

## Relier Alertmanager au courrier

À faire une fois, puis après toute reconstruction du cluster. Ni l'identifiant SMTP ni l'adresse du destinataire ne sont dans le dépôt : le premier vient du state du bootstrap, la seconde d'un fichier du poste.

1. Écrire l'adresse qui recevra les alertes dans un fichier fermé aux autres comptes, avec un éditeur :

```bash
install -D -m 600 /dev/null ~/.config/rtgre-platform/alert-recipient
```

2. Depuis la racine du dépôt, avec `terraform/bootstrap` initialisé :

```bash
scripts/alertmanager-email.sh
```

Le script crée le Secret `alertmanager-email`, remplace le pod d'Alertmanager, envoie une alerte d'essai, puis vérifie dans les métriques que le serveur d'envoi l'a acceptée. Le message arrive en moins d'une minute, et son message « Résolu » cinq minutes après.

## Changer de destinataire

Modifier le fichier du poste, puis relancer `scripts/alertmanager-email.sh`.

## Envoyer une alerte d'essai

```bash
scripts/alertmanager-email.sh --test
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

Regarder d'abord le dossier des indésirables. Puis lire le journal : Alertmanager n'y écrit que la première tentative de chaque envoi.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n monitoring logs alertmanager-monitoring-alertmanager-0 -c alertmanager --since 1h | grep 'level=WARN'"
```

| Constat | Cause | Que faire |
| --- | --- | --- |
| Le pod reste à `Init:0/1` | Le Secret n'existe pas, par exemple après une reconstruction du cluster. | Relier Alertmanager au courrier. |
| `Envelope From address … not authorized` | La politique `rtgre-platform-alerts` ne désigne plus le groupe de l'utilisateur SMTP. | Depuis `terraform/bootstrap` : `terraform apply -replace=oci_identity_policy.alerts` |
| Une erreur `535` à la commande `AUTH` | L'identifiant SMTP a été supprimé ou renouvelé. | Relancer `scripts/alertmanager-email.sh`, qui relit le state. |
| `Quota Exceeded` | Le plafond quotidien est atteint, ou un quota vient de changer : Oracle met plusieurs minutes à l'appliquer. | Attendre. Le plafond est `mails_per_day`, dans `terraform/bootstrap/free-tier.auto.tfvars`. |
| `i/o timeout` | Le serveur d'envoi est injoignable, ou son nom a changé. | Vérifier `alerting.email.smarthost` dans `kubernetes/monitoring/values.yaml` : c'est le seul nom qu'Alertmanager peut joindre. |
| Rien dans le journal | Aucune alerte n'est partie de Prometheus, ou le message a été accepté. | Envoyer une alerte d'essai. Si elle est acceptée sans arriver, l'adresse est peut-être sur la liste de suppression d'Oracle après un rejet : console d'Oracle, Email Delivery, « Suppression List ». |

## Renouveler l'identifiant SMTP

Depuis `terraform/bootstrap`, puis depuis la racine du dépôt :

```bash
terraform apply -replace=oci_identity_domains_smtp_credential.alerts
```

```bash
scripts/alertmanager-email.sh
```

## Ce que les alertes ne voient pas

Prometheus et Alertmanager tournent sur le cluster qu'ils surveillent. Si le nœud de travail tombe, ou tout le cluster, aucune alerte ne part. Le workflow `Watch` couvre ce cas : il sonde le site depuis GitHub et ouvre une issue « Incident » ([site-injoignable](site-injoignable.md)).
