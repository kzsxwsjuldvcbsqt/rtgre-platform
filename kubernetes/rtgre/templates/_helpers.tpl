{{/* Étiquettes communes. */}}
{{- define "rtgre.labels" -}}
app.kubernetes.io/name: rtgre
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Sécurité des pods : sans privilège, et le volume est donné au groupe commun. */}}
{{- define "rtgre.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ .user }}
runAsGroup: {{ .user }}
fsGroup: {{ .root.Values.user }}
fsGroupChangePolicy: OnRootMismatch
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/*
Résolution DNS : le nom d'ADE est demandé tel quel, sans essayer d'abord les domaines du cluster.
Le proxy DNS de Cilium refuse tout autre nom, et un refus arrêterait la recherche.
*/}}
{{- define "rtgre.dnsConfig" -}}
options:
  - name: ndots
    value: "1"
{{- end }}

{{/* Sécurité des conteneurs : aucune capacité, système de fichiers en lecture seule. */}}
{{- define "rtgre.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
{{- end }}

{{/* Conteneur du générateur, commun à la tâche horaire et au démarrage du serveur web. */}}
{{- define "rtgre.generatorContainer" -}}
image: {{ .Values.generator.image.repository }}:{{ .Values.generator.image.tag }}
securityContext:
  {{- include "rtgre.containerSecurityContext" . | nindent 2 }}
  runAsUser: {{ .Values.user }}
  runAsGroup: {{ .Values.user }}
env:
  - name: SCHEDULE_OUTPUT_ROOT
    value: {{ .Values.site.mountPath }}
resources:
  {{- toYaml .Values.generator.resources | nindent 2 }}
volumeMounts:
  - name: site
    mountPath: {{ .Values.site.mountPath }}
{{- end }}

{{/* Configuration de nginx : files/nginx.conf, où les valeurs du chart sont rendues. */}}
{{- define "rtgre.nginxConfig" -}}
{{ tpl (.Files.Get "files/nginx.conf") . }}
{{- end }}
