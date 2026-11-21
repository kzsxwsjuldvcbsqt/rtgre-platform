"""Écrit les tableaux de bord Grafana de kubernetes/monitoring/files/dashboards.

    python3 scripts/grafana-dashboards.py kubernetes/monitoring/files/dashboards

Chaque requête doit être vérifiée dans Prometheus avant d'entrer dans un tableau.
"""
import json, sys

DS = {"type": "prometheus", "uid": "prometheus"}


LOKI = {"type": "loki", "uid": "loki"}


def stat(title, expr, unit="none", steps=None, x=0, y=0, w=6, decimals=None, description="", source=None):
    source = source or DS
    steps = steps or [{"color": "green", "value": None}]
    defaults = {"unit": unit, "thresholds": {"mode": "absolute", "steps": steps}, "color": {"mode": "thresholds"}}
    if decimals is not None:
        defaults["decimals"] = decimals
    target = {"datasource": source, "expr": expr, "refId": "A"}
    target.update({"queryType": "instant"} if source is LOKI else {"instant": True})
    return {"type": "stat", "title": title, "description": description, "datasource": source,
            "gridPos": {"h": 4, "w": w, "x": x, "y": y},
            "targets": [target],
            "fieldConfig": {"defaults": defaults, "overrides": []},
            "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                        "colorMode": "value", "graphMode": "none", "textMode": "auto"}}


def series(title, expr, legend, unit="none", x=0, y=0, w=12, h=8, maximum=None, description="", source=None):
    source = source or DS
    defaults = {"unit": unit, "min": 0, "custom": {"drawStyle": "line", "lineWidth": 1, "fillOpacity": 10,
                                                   "showPoints": "never", "spanNulls": True}}
    if maximum is not None:
        defaults["max"] = maximum
    return {"type": "timeseries", "title": title, "description": description, "datasource": source,
            "gridPos": {"h": h, "w": w, "x": x, "y": y},
            "targets": [{"datasource": source, "expr": expr, "legendFormat": legend, "refId": "A"}],
            "fieldConfig": {"defaults": defaults, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
                        "tooltip": {"mode": "multi", "sort": "desc"}}}


def dashboard(uid, title, description, panels, time_from="now-24h"):
    for index, panel in enumerate(panels, 1):
        panel["id"] = index
    return {"uid": uid, "title": title, "description": description, "tags": ["rtgre-platform"],
            "schemaVersion": 39, "version": 1, "editable": False, "graphTooltip": 1,
            "time": {"from": time_from, "to": "now"}, "refresh": "1m", "timezone": "Europe/Paris",
            "templating": {"list": []}, "annotations": {"list": []}, "panels": panels}


GREEN = {"color": "green", "value": None}
CONTAINERS = 'container!="", container!="POD"'
ROOT = 'mountpoint="/", fstype!~"tmpfs|overlay"'

platform = dashboard("plateforme", "Plateforme", "État des nœuds et du cluster.", [
    stat("Nœuds prêts", 'sum(kube_node_status_condition{condition="Ready", status="true"})',
         steps=[{"color": "red", "value": None}, {"color": "green", "value": 2}], x=0),
    stat("Pods en service", 'sum(kube_pod_status_phase{phase="Running"})', x=6),
    stat("Pods en attente ou en échec", 'sum(kube_pod_status_phase{phase=~"Pending|Failed"})',
         steps=[GREEN, {"color": "orange", "value": 1}], x=12),
    stat("Cibles de Prometheus injoignables", 'count(up == 0) or vector(0)',
         steps=[GREEN, {"color": "red", "value": 1}], x=18),
    series("Processeur occupé, par nœud",
           '100 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100',
           "{{instance}}", unit="percent", maximum=100, x=0, y=4),
    series("Mémoire utilisée, par nœud",
           '(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100',
           "{{instance}}", unit="percent", maximum=100, x=12, y=4),
    series("Disque utilisé, par nœud",
           '(1 - node_filesystem_avail_bytes{%s} / node_filesystem_size_bytes{%s}) * 100' % (ROOT, ROOT),
           "{{instance}}", unit="percent", maximum=100, x=0, y=12,
           description="Disque de démarrage, qui porte aussi les volumes locaux et les images."),
    series("Charge sur 5 minutes, par nœud", 'node_load5', "{{instance}}", x=12, y=12,
           description="Chaque nœud a un seul cœur : au-dessus de 1, des tâches attendent."),
    series("Mémoire, par espace de noms",
           'sum by (namespace) (container_memory_working_set_bytes{%s})' % CONTAINERS,
           "{{namespace}}", unit="bytes", x=0, y=20),
    series("Processeur, par espace de noms",
           'sum by (namespace) (rate(container_cpu_usage_seconds_total{%s}[5m]))' % CONTAINERS,
           "{{namespace}}", unit="none", x=12, y=20, description="En cœurs."),
    stat("Applications Argo CD désynchronisées ou dégradées",
         'count(argocd_app_info{sync_status!="Synced"} or argocd_app_info{health_status!="Healthy"}) or vector(0)',
         steps=[GREEN, {"color": "orange", "value": 1}], x=0, y=28,
         description="Une application qui ne correspond plus au dépôt, ou dont les objets ne sont pas sains."),
    stat("Certificats non prêts", 'count(certmanager_certificate_ready_status{condition="True"} == 0) or vector(0)',
         steps=[GREEN, {"color": "red", "value": 1}], x=6, y=28),
    stat("Alertes en cours", 'count(ALERTS{alertstate="firing"}) or vector(0)',
         steps=[GREEN, {"color": "red", "value": 1}], x=12, y=28,
         description="Chacune est aussi envoyée sur Telegram, avec son runbook."),
    stat("Données de Prometheus sur le disque", 'prometheus_tsdb_storage_blocks_bytes + prometheus_tsdb_wal_storage_size_bytes',
         unit="bytes", x=18, y=28, steps=[GREEN, {"color": "orange", "value": 3500000000}],
         description="Bornées à 4 Go, sur un volume de 5 Go."),
    series("Redémarrages de conteneurs sur une heure",
           'sum by (namespace, pod) (increase(kube_pod_container_status_restarts_total[1h])) > 0',
           "{{namespace}}/{{pod}}", x=0, y=32, w=24, h=6,
           description="Vide quand rien ne redémarre."),
])

GENERATOR = 'namespace="rtgre", cronjob="rtgre-generator"'
SITE = 'job="site"'
VISITS = '{namespace="rtgre", container="nginx"}'
rtgre = dashboard("rtgre", "rtgre", "Le site rtgre.fr : disponibilité, certificat, trafic et génération horaire.", [
    stat("Site joignable", 'min(probe_success{%s})' % SITE, x=0, w=4,
         steps=[{"color": "red", "value": None}, {"color": "green", "value": 1}],
         description="1 quand la sonde du cluster obtient le site en HTTPS, sous chacun de ses noms. 0 sinon."),
    stat("Temps de réponse", 'max(probe_duration_seconds{%s})' % SITE, unit="s", x=4, w=4, decimals=3,
         steps=[GREEN, {"color": "orange", "value": 1}, {"color": "red", "value": 3}],
         description="Durée de la requête la plus lente de la sonde, redirections comprises."),
    stat("Certificat : jours restants", 'min(probe_ssl_earliest_cert_expiry{%s} - time()) / 86400' % SITE,
         x=8, w=4, decimals=0,
         steps=[{"color": "red", "value": None}, {"color": "orange", "value": 14}, {"color": "green", "value": 25}],
         description="cert-manager renouvelle un mois avant l'expiration : sous 25 jours, le renouvellement a échoué."),
    stat("Dernière génération réussie", 'time() - kube_cronjob_status_last_successful_time{%s}' % GENERATOR,
         unit="s", x=12, w=4, steps=[GREEN, {"color": "orange", "value": 4500}, {"color": "red", "value": 10800}],
         description="Le site est régénéré chaque heure. Orange après une génération manquée, rouge après trois heures."),
    stat("Serveur web prêt", 'kube_deployment_status_replicas_ready{namespace="rtgre", deployment="rtgre-web"}',
         x=16, w=4, steps=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
    stat("Âge des journaux de visite", 'time() - max(kube_pod_start_time{namespace="rtgre", pod=~"rtgre-web-.*"})',
         unit="s", x=20, w=4, steps=[GREEN, {"color": "orange", "value": 691200}, {"color": "red", "value": 1209600}],
         description="Les journaux disparaissent avec le pod, remplacé chaque lundi. Rouge au-delà de quatorze jours (ADR 0014)."),
    series("Disponibilité sur une heure glissante", 'avg_over_time(probe_success{%s}[1h]) * 100' % SITE,
           "{{instance}}", unit="percent", maximum=100, x=0, y=4),
    series("Temps de réponse de la sonde", 'probe_duration_seconds{%s}' % SITE, "{{instance}}", unit="s", x=12, y=4),
    series("Requêtes HTTPS par seconde, par code de réponse",
           'sum by (code) (rate(traefik_entrypoint_requests_total{entrypoint="websecure"}[5m]))',
           "{{code}}", unit="reqps", x=0, y=12,
           description="Vues par la passerelle, sonde du cluster comprise. Aucune adresse de visiteur n'y figure."),
    series("Durée des requêtes à la passerelle, 95e centile",
           'histogram_quantile(0.95, sum by (le) (rate(traefik_entrypoint_request_duration_seconds_bucket{entrypoint="websecure"}[5m])))',
           "95e centile", unit="s", x=12, y=12),
    stat("Requêtes servies sur 24 heures", 'sum(count_over_time(%s [24h]))' % VISITS, x=0, y=20, w=6, source=LOKI,
         description="Lignes du journal de nginx : pages, feuilles de style, scripts. Les sondes n'y figurent pas."),
    stat("Réseaux distincts sur 24 heures",
         'count(sum by (network) (count_over_time(%s | pattern "<_> <network> <_>" [24h])))' % VISITS,
         x=6, y=20, w=6, source=LOKI,
         description="Nombre approché de visiteurs : le journal ne garde que le réseau de chacun (ADR 0014)."),
    series("Requêtes servies par heure, par code de réponse",
           'sum by (status) (count_over_time(%s | pattern "<_> <_> \\"<_>\\" <status> <_>" [1h]))' % VISITS,
           "{{status}}", x=12, y=20, h=4, source=LOKI),
    series("Durée des générations",
           'kube_job_status_completion_time{namespace="rtgre", job_name=~"rtgre-generator-.*"} - kube_job_status_start_time{namespace="rtgre", job_name=~"rtgre-generator-.*"}',
           "{{job_name}}", unit="s", x=0, y=24),
    series("Générations en échec",
           'sum(kube_job_status_failed{namespace="rtgre", job_name=~"rtgre-generator-.*"}) or vector(0)',
           "échecs conservés", x=12, y=24, description="Le cluster garde les trois derniers échecs."),
    series("Mémoire des pods",
           'sum by (pod) (container_memory_working_set_bytes{namespace="rtgre", %s})' % CONTAINERS,
           "{{pod}}", unit="bytes", x=0, y=32),
    series("Processeur des pods",
           'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="rtgre", %s}[5m]))' % CONTAINERS,
           "{{pod}}", x=12, y=32, description="En cœurs."),
])

for name, content in (("plateforme", platform), ("rtgre", rtgre)):
    with open(f"{sys.argv[1]}/{name}.json", "w", encoding="utf-8") as handle:
        json.dump(content, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
