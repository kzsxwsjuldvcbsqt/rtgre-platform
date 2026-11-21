#!/usr/bin/env bash
# Vérifie les alertes de kubernetes/monitoring : syntaxe et tests des règles, existence de
# chaque runbook cité, puis configuration et message d'Alertmanager tels que le chart les rend.
#
#   scripts/ci/validate-alerting.sh
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
chart=$repo/kubernetes/monitoring
rules=$chart/files/alerts.yaml
runbooks=$repo/docs/runbooks

echo "== règles"
promtool check rules "$rules"
promtool test rules "$chart"/tests/*_test.yaml

echo "== runbooks"
missing=0
while read -r runbook; do
  if [ ! -f "$runbooks/$runbook" ]; then
    echo "Runbook introuvable : docs/runbooks/$runbook" >&2
    missing=1
  fi
done < <(sed -n 's/^ *runbook: //p' "$rules" | sort --unique)
[ "$missing" -eq 0 ]
echo "Chaque runbook cité existe."

echo "== Alertmanager"
workdir=$(mktemp --directory)
trap 'rm -rf "$workdir"' EXIT
# Le chart range la configuration et le gabarit du message dans un Secret, encodés en base64.
helm dependency build "$chart" > /dev/null
helm template monitoring "$chart" --namespace monitoring --api-versions monitoring.coreos.com/v1 \
  --api-versions cert-manager.io/v1 \
  --show-only charts/kube-prometheus-stack/templates/alertmanager/secret.yaml |
  awk '$1 ~ /^(alertmanager\.yaml|.+\.tmpl):$/ { gsub(/"/, "", $2); sub(/:$/, "", $1); print $1, $2 }' |
  while read -r name content; do
    printf '%s' "$content" | base64 --decode > "$workdir/$name"
  done
[ -s "$workdir/alertmanager.yaml" ]
# Dans le pod, les gabarits sont à côté de la configuration.
sed --in-place "s#/etc/alertmanager/config#$workdir#" "$workdir/alertmanager.yaml"
amtool check-config "$workdir/alertmanager.yaml"
# Chaque gabarit de message cité par la configuration doit se rendre.
grep --only-matching '{{ template "[^"]*" \. }}' "$workdir/alertmanager.yaml" | sort --unique |
  while read -r text; do
    amtool template render --template.glob "$workdir/*.tmpl" --template.text "$text" > /dev/null
    echo "Gabarit rendu : $text"
  done
