#!/usr/bin/env bash
# Retente un terraform apply tant qu'Oracle répond « Out of host capacity ».
#
# À lancer depuis le dossier d'une configuration Terraform déjà initialisée :
#   ../../../scripts/apply-until-capacity.sh [tentatives] [attente en secondes]
#
# Chaque tentative recalcule le plan et s'arrête si celui-ci contient autre chose que des
# créations d'instances : le script ne peut pas appliquer une modification inattendue.
set -euo pipefail

max_attempts=${1:-24}
wait_seconds=${2:-600}
plan_file=$(mktemp --suffix=.tfplan)
trap 'rm -f "$plan_file"' EXIT

count_changes() {
  terraform show -json "$plan_file" | jq "$1"
}

for attempt in $(seq 1 "$max_attempts"); do
  echo "$(date -u +%H:%M:%S) tentative $attempt/$max_attempts"

  terraform plan -input=false -no-color -out="$plan_file" >/dev/null

  unexpected=$(count_changes '[.resource_changes[]
    | select(.change.actions != ["no-op"])
    | select((.type == "oci_core_instance" and .change.actions == ["create"]) | not)] | length')
  if [ "$unexpected" != "0" ]; then
    echo "Le plan contient autre chose que des créations d'instances : arrêt." >&2
    exit 3
  fi

  pending=$(count_changes '[.resource_changes[] | select(.change.actions == ["create"])] | length')
  if [ "$pending" = "0" ]; then
    echo "Toutes les instances existent."
    exit 0
  fi

  if output=$(terraform apply -input=false -no-color "$plan_file" 2>&1); then
    echo "Instances créées."
    exit 0
  fi

  if ! grep -q 'Out of host capacity' <<< "$output"; then
    echo "$output" >&2
    echo "Erreur autre qu'un manque de capacité : arrêt." >&2
    exit 4
  fi

  echo "  capacité indisponible, nouvel essai dans ${wait_seconds} s"
  sleep "$wait_seconds"
done

echo "Capacité toujours indisponible après $max_attempts tentatives." >&2
exit 1
