# Métriques et alertes

Prometheus collecte les métriques du cluster et les garde quinze jours ([ADR 0015](../../docs/adr/0015-metriques-avec-prometheus-et-son-operateur.md)). Il évalue aussi les règles d'alerte, qu'Alertmanager envoie par courrier ([ADR 0018](../../docs/adr/0018-alertes-avec-alertmanager-et-telegram.md), [ADR 0021](../../docs/adr/0021-envoyer-les-alertes-par-courrier.md)).

| Composant | Rôle |
| --- | --- |
| Prometheus | Collecte les cibles chaque minute, sur un volume local déclaré dans [`storage`](../storage) |
| Opérateur | Traduit les objets ServiceMonitor et PrometheusRule en configuration de Prometheus |
| kube-state-metrics | Expose l'état des objets du cluster : pods, déploiements, tâches |
| Sonde (blackbox exporter) | Interroge le site en HTTPS chaque minute, comme un visiteur |
| Grafana | Affiche les tableaux de bord du dépôt, en lecture seule et sans compte ([ADR 0016](../../docs/adr/0016-grafana-en-lecture-seule-sans-compte.md)) |
| Alertmanager | Regroupe les alertes et les envoie par courrier ; le serveur d'envoi est la seule adresse qu'il peut joindre |
| [`node-exporter`](../node-exporter) | Métriques des nœuds, dans sa propre application |

## Ce qui est collecté

| Cible | Ce qu'elle donne |
| --- | --- |
| `kubelet` | Processeur et mémoire de chaque conteneur, volumes |
| `apiserver` | Requêtes à l'API de Kubernetes |
| `coredns` | Résolutions DNS du cluster |
| `kube-state-metrics` | État des objets, dernière réussite des tâches planifiées |
| `prometheus-node-exporter` | Processeur, mémoire, disque et réseau des deux nœuds |
| `site` | Disponibilité, temps de réponse et expiration du certificat de rtgre.fr et de www.rtgre.fr |
| `gateway-traefik-metrics` | Requêtes, codes de réponse et durées à la passerelle, sans aucune adresse de visiteur |
| `cert-manager` | État et date d'expiration de chaque certificat |
| `argocd-application-controller-metrics` | Synchronisation et santé de chaque application |

Le planificateur, le gestionnaire de contrôleurs, etcd et kube-proxy ne le sont pas : kubeadm ne les fait écouter que sur la boucle locale du plan de contrôle.

## La sonde du site

Elle part du cluster, résout le nom public et passe par le load balancer : elle voit donc ce que voit un visiteur, hormis une panne du réseau entre lui et Oracle. Ses adresses sont dans `probes.targets`, et elle ne peut joindre qu'elles. Une réponse en clair, un certificat invalide ou un code autre que 200 après redirections comptent comme un échec.

## Ajouter une cible

1. Dans le chart du composant, un ServiceMonitor, et une règle réseau qui laisse entrer les pods de Prometheus (`app.kubernetes.io/name: prometheus`, espace de noms `monitoring`) sur le port des métriques.
2. Ici, une entrée dans `scrape.pods` de [`values.yaml`](values.yaml) : Prometheus ne sort que vers ce qui y figure.

## Alertes

Les règles sont dans [`files/alerts.yaml`](files/alerts.yaml), au format de Prometheus. Recevoir les alertes, en essayer une ou en faire taire une : [runbook](../../docs/runbooks/recevoir-les-alertes.md).

| Alerte | Se déclenche quand | Runbook |
| --- | --- | --- |
| `SiteInjoignable` | La sonde échoue depuis 5 minutes | [site-injoignable](../../docs/runbooks/site-injoignable.md) |
| `GenerationEnEchec` | Aucune génération réussie depuis 3 heures | [suivre-la-generation-du-site](../../docs/runbooks/suivre-la-generation-du-site.md) |
| `CertificatExpireBientot` | Un certificat expire dans moins de 14 jours | [suivre-les-certificats](../../docs/runbooks/suivre-les-certificats.md) |
| `CertificatNonPret` | Un certificat n'est pas prêt depuis 1 heure | [suivre-les-certificats](../../docs/runbooks/suivre-les-certificats.md) |
| `JournauxDeVisiteTropAnciens` | Le serveur web n'a pas été remplacé depuis 8 jours | [retablir-la-conservation-des-journaux](../../docs/runbooks/retablir-la-conservation-des-journaux.md) |
| `ConservationDeLokiEnPanne` | Loki n'a rien supprimé depuis 6 heures | [retablir-la-conservation-des-journaux](../../docs/runbooks/retablir-la-conservation-des-journaux.md) |
| `NoeudDisquePresquePlein` | Moins de 25 % de place sur un nœud | [noeud-a-court-de-ressources](../../docs/runbooks/noeud-a-court-de-ressources.md) |
| `NoeudMemoirePresquePleine` | Moins de 10 % de mémoire disponible sur un nœud | [noeud-a-court-de-ressources](../../docs/runbooks/noeud-a-court-de-ressources.md) |
| `PodEnBoucle` | Un conteneur redémarre 3 fois en 30 minutes | [diagnostiquer-un-pod](../../docs/runbooks/diagnostiquer-un-pod.md) |
| `CibleInjoignable` | Prometheus ne joint plus une cible depuis 15 minutes | [diagnostiquer-un-pod](../../docs/runbooks/diagnostiquer-un-pod.md) |
| `ApplicationDesynchronisee` | Une application Argo CD diffère du dépôt depuis 30 minutes | [retablir-une-application-argocd](../../docs/runbooks/retablir-une-application-argocd.md) |
| `ApplicationDegradee` | Une application Argo CD n'est pas saine depuis 90 minutes, plus que le temps d'une génération manquée | [retablir-une-application-argocd](../../docs/runbooks/retablir-une-application-argocd.md) |

Seule la première est `critical`, rappelée toutes les deux heures. Les autres sont `warning`, rappelées chaque jour.

### Ajouter une alerte

1. La règle, dans `files/alerts.yaml`, avec son niveau, un résumé, une description et l'annotation `runbook`, le nom d'un fichier de [`docs/runbooks`](../../docs/runbooks).
2. Son test, dans [`tests/alerts_test.yaml`](tests/alerts_test.yaml) : un instant où elle se tait, un instant où elle se déclenche.
3. Vérifier :

```bash
scripts/ci/validate-alerting.sh
```

## Tableaux de bord

| Tableau | Contenu |
| --- | --- |
| Plateforme | Nœuds prêts, pods, processeur, mémoire, disque et charge par nœud, consommation par espace de noms, applications Argo CD, certificats, alertes en cours, redémarrages |
| rtgre | Site joignable, temps de réponse, jours restants du certificat, trafic à la passerelle, requêtes servies et réseaux distincts sur 24 heures, génération horaire, âge des journaux de visite |

Ils sont dans [`files/dashboards`](files/dashboards), générés par [`scripts/grafana-dashboards.py`](../../scripts/grafana-dashboards.py). Pour en modifier un : changer le script, le relancer, vérifier la requête dans Prometheus, puis ouvrir une pull request.

```bash
python3 scripts/grafana-dashboards.py kubernetes/monitoring/files/dashboards
```

Grafana relit le dossier toutes les trente secondes : aucun redémarrage n'est nécessaire.

## Ouvrir Grafana

Depuis la racine du dépôt, après avoir ouvert les sessions du Bastion :

```bash
ssh -t -F ansible/.ssh/bastion.conf -L 8080:127.0.0.1:8080 cp-1 kubectl -n monitoring port-forward svc/monitoring-grafana 8080:80
```

Puis ouvrir <http://localhost:8080>. Il n'y a ni identifiant ni mot de passe : le tableau « rtgre » s'affiche, et rien ne peut être modifié. Si le port 8080 est pris sur le poste, changer le premier nombre.

## Ouvrir l'interface de Prometheus

Pour une requête ponctuelle ou l'état des cibles. Elle n'est pas exposée non plus. Depuis la racine du dépôt, après avoir ouvert les sessions du Bastion ([se-connecter-a-un-noeud](../../docs/runbooks/se-connecter-a-un-noeud.md)) :

```bash
ssh -t -F ansible/.ssh/bastion.conf -L 8080:127.0.0.1:8080 cp-1 kubectl -n monitoring port-forward svc/monitoring-prometheus 8080:9090
```

Puis ouvrir <http://localhost:8080>. La page « Target health » liste les cibles et leur état. C'est le même port que pour [Argo CD](../../docs/runbooks/acceder-a-argocd.md) : sshd n'en autorise qu'un, donc une interface à la fois. Si le port 8080 est pris sur le poste, changer le premier nombre.

## Choix notables

- **Conservation bornée deux fois** : quinze jours, et 4 Go, sur un volume de 5 Go. Le disque du nœud ne peut pas se remplir de métriques.
- **Toute cible déclarée est candidate**, quel que soit son chart : Prometheus ne filtre pas sur une étiquette de release. Le filtre est la règle réseau.
- **Des règles d'alerte écrites pour ce cluster**, plutôt que celles du chart : douze, chacune avec son test et son runbook.
- **Alertmanager sans volume ni jeton de l'API** : il ne garde que des silences, et n'a rien à demander à Kubernetes.
- **Ni l'identifiant SMTP ni le destinataire ne sont dans le dépôt** : la configuration les désigne par `$(SMTP_USERNAME)` et `$(ALERT_RECIPIENT)`, que les conteneurs qui la préparent remplacent par les valeurs d'un Secret.
- **Retirer l'application ne supprime rien** : ses CRD emporteraient les cibles et les règles des autres charts.
