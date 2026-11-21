"""Écrit les tableaux de bord Grafana de kubernetes/monitoring/files/dashboards.

    python3 scripts/grafana-dashboards.py kubernetes/monitoring/files/dashboards

Chaque requête doit être vérifiée dans Prometheus avant d'entrer dans un tableau.
"""
import json, sys

DS = {"type": "prometheus", "uid": "prometheus"}


def stat(title, expr, unit="none", steps=None, x=0, y=0, w=6, decimals=None, description=""):
    steps = steps or [{"color": "green", "value": None}]
    defaults = {"unit": unit, "thresholds": {"mode": "absolute", "steps": steps}, "color": {"mode": "thresholds"}}
    if decimals is not None:
        defaults["decimals"] = decimals
    return {"type": "stat", "title": title, "description": description, "datasource": DS,
            "gridPos": {"h": 4, "w": w, "x": x, "y": y},
            "targets": [{"datasource": DS, "expr": expr, "instant": True, "refId": "A"}],
            "fieldConfig": {"defaults": defaults, "overrides": []},
            "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                        "colorMode": "value", "graphMode": "none", "textMode": "auto"}}


def series(title, expr, legend, unit="none", x=0, y=0, w=12, h=8, maximum=None, description=""):
    defaults = {"unit": unit, "min": 0, "custom": {"drawStyle": "line", "lineWidth": 1, "fillOpacity": 10,
                                                   "showPoints": "never", "spanNulls": True}}
    if maximum is not None:
        defaults["max"] = maximum
    return {"type": "timeseries", "title": title, "description": description, "datasource": DS,
            "gridPos": {"h": h, "w": w, "x": x, "y": y},
            "targets": [{"datasource": DS, "expr": expr, "legendFormat": legend, "refId": "A"}],
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
    series("Redémarrages de conteneurs sur une heure",
           'sum by (namespace, pod) (increase(kube_pod_container_status_restarts_total[1h])) > 0',
           "{{namespace}}/{{pod}}", x=0, y=28, w=24, h=6,
           description="Vide quand rien ne redémarre."),
])

GENERATOR = 'namespace="rtgre", cronjob="rtgre-generator"'
rtgre = dashboard("rtgre", "rtgre", "Le site rtgre.fr : génération horaire et serveur web.", [
    stat("Dernière génération réussie", 'time() - kube_cronjob_status_last_successful_time{%s}' % GENERATOR,
         unit="s", x=0, steps=[GREEN, {"color": "orange", "value": 4500}, {"color": "red", "value": 10800}],
         description="Le site est régénéré chaque heure. Orange après une génération manquée, rouge après trois heures."),
    stat("Serveur web prêt", 'kube_deployment_status_replicas_ready{namespace="rtgre", deployment="rtgre-web"}',
         x=6, steps=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
    stat("Redémarrages sur 24 heures", 'sum(increase(kube_pod_container_status_restarts_total{namespace="rtgre"}[24h]))',
         x=12, decimals=0, steps=[GREEN, {"color": "orange", "value": 1}]),
    stat("Âge des journaux de visite", 'time() - max(kube_pod_start_time{namespace="rtgre", pod=~"rtgre-web-.*"})',
         unit="s", x=18, steps=[GREEN, {"color": "orange", "value": 691200}, {"color": "red", "value": 1209600}],
         description="Les journaux disparaissent avec le pod, remplacé chaque lundi. Rouge au-delà de quatorze jours (ADR 0014)."),
    series("Durée des générations",
           'kube_job_status_completion_time{namespace="rtgre", job_name=~"rtgre-generator-.*"} - kube_job_status_start_time{namespace="rtgre", job_name=~"rtgre-generator-.*"}',
           "{{job_name}}", unit="s", x=0, y=4),
    series("Générations en échec",
           'sum(kube_job_status_failed{namespace="rtgre", job_name=~"rtgre-generator-.*"}) or vector(0)',
           "échecs conservés", x=12, y=4, description="Le cluster garde les trois derniers échecs."),
    series("Mémoire des pods",
           'sum by (pod) (container_memory_working_set_bytes{namespace="rtgre", %s})' % CONTAINERS,
           "{{pod}}", unit="bytes", x=0, y=12),
    series("Processeur des pods",
           'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="rtgre", %s}[5m]))' % CONTAINERS,
           "{{pod}}", x=12, y=12, description="En cœurs."),
])

for name, content in (("plateforme", platform), ("rtgre", rtgre)):
    with open(f"{sys.argv[1]}/{name}.json", "w", encoding="utf-8") as handle:
        json.dump(content, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
