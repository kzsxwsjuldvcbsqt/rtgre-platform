{{/*
Lignes utiles de files/signed-images.txt : une liste de dictionnaires prefix, identity, issuer.
*/}}
{{- define "kyverno.signedImages" -}}
{{- $images := list -}}
{{- range $line := splitList "\n" (.Files.Get "files/signed-images.txt") -}}
{{- $line = trim $line -}}
{{- if and $line (not (hasPrefix "#" $line)) -}}
{{- $fields := splitList "|" $line -}}
{{- if ne (len $fields) 3 -}}
{{- fail (printf "files/signed-images.txt : trois champs attendus dans « %s »" $line) -}}
{{- end -}}
{{- $images = append $images (dict "prefix" (trim (index $fields 0)) "identity" (trim (index $fields 1)) "issuer" (trim (index $fields 2))) -}}
{{- end -}}
{{- end -}}
{{- toYaml (dict "images" $images) -}}
{{- end -}}

{{/*
Sélecteur des espaces de noms où les images sont contrôlées.
*/}}
{{- define "kyverno.verifiedNamespaces" -}}
matchLabels:
  {{ .Values.verifiedNamespaces.label }}: {{ .Values.verifiedNamespaces.value }}
{{- end -}}
