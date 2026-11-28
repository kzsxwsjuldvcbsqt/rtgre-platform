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

{{/*
Pod du générateur, commun à la tâche horaire et à la génération qui suit un déploiement.
Paramètres : « root », le contexte du chart, et « command », facultatif, qui remplace la commande
de l'image.
*/}}
{{- define "rtgre.generatorPod" -}}
metadata:
  labels:
    {{- include "rtgre.labels" .root | nindent 4 }}
    app.kubernetes.io/component: generator
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  dnsConfig:
    {{- include "rtgre.dnsConfig" .root | nindent 4 }}
  securityContext:
    {{- include "rtgre.podSecurityContext" (dict "root" .root "user" .root.Values.user) | nindent 4 }}
  containers:
    - name: generator
      {{- include "rtgre.generatorContainer" .root | nindent 6 }}
      {{- with .command }}
      command:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  volumes:
    - name: site
      persistentVolumeClaim:
        claimName: {{ .root.Values.site.claimName }}
{{- end }}

{{/* Configuration de nginx : files/nginx.conf, où les valeurs du chart sont rendues. */}}
{{- define "rtgre.nginxConfig" -}}
{{ tpl (.Files.Get "files/nginx.conf") . }}
{{- end }}
