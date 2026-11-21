# Loki en un seul processus, sur le disque : pas de stockage objet, pas de réplication.
auth_enabled: false

server:
  http_listen_port: {{ .Values.loki.port }}
  grpc_listen_port: 9095
  log_level: warn

common:
  path_prefix: /var/loki
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory
  storage:
    filesystem:
      chunks_directory: /var/loki/chunks
      rules_directory: /var/loki/rules

schema_config:
  configs:
    - from: "2026-11-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  # Tout journal est supprimé passé ce délai, quel que soit le pod qui l'a écrit.
  retention_period: {{ .Values.loki.retention }}
  ingestion_rate_mb: 4
  ingestion_burst_size_mb: 8
  volume_enabled: true

compactor:
  working_directory: /var/loki/compactor
  retention_enabled: true
  delete_request_store: filesystem
  compaction_interval: 10m
  retention_delete_delay: {{ .Values.loki.retentionDeleteDelay }}

# Aucune statistique envoyée à l'éditeur.
analytics:
  reporting_enabled: false
