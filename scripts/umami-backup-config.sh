#!/usr/bin/env bash
# Indique à la sauvegarde d'Umami où déposer : le bucket des sauvegardes et le namespace Object
# Storage de la tenancy, lus dans les sorties du bootstrap. Aucun des deux n'est un secret, mais
# ils sont propres à la tenancy et restent hors du dépôt.
#
#   scripts/bastion-ssh-config.sh
#   scripts/umami-backup-config.sh
#
# Le script crée ou remplace le ConfigMap : il se relance sans risque, après une reconstruction
# du cluster par exemple.
#
# Variable facultative :
#   RTGRE_SSH_CONFIG   configuration SSH (défaut : ansible/.ssh/bastion.conf)
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
config=${RTGRE_SSH_CONFIG:-$repo/ansible/.ssh/bastion.conf}
bootstrap=$repo/terraform/bootstrap
values=$repo/kubernetes/umami/values.yaml

namespace=$(awk '/^  umami:/ { found = 1; next } found && $1 == "namespace:" { print $2; exit }' \
  "$repo/kubernetes/apps/values.yaml")
configmap=$(awk '/^backup:/ { found = 1; next } found && $1 == "configName:" { print $2; exit }' "$values")
: "${namespace:?espace de noms umami introuvable dans kubernetes/apps/values.yaml}"
: "${configmap:?backup.configName est introuvable dans $values}"

bucket=$(terraform -chdir="$bootstrap" output -raw backup_bucket)
storage_namespace=$(terraform -chdir="$bootstrap" output -raw objectstorage_namespace)

# Premier hôte de la configuration du Bastion dont le nom commence par cp-.
control_plane=$(awk '$1 == "Host" { for (i = 2; i <= NF; i++) if ($i ~ /^cp-/) { print $i; exit } }' "$config")

# ssh recolle ses arguments avant de les passer au shell du nœud : chacun est protégé d'abord.
remote_kubectl() {
  local command
  command=$(printf '%q ' kubectl --namespace "$namespace" "$@")
  ssh -F "$config" -o BatchMode=yes -o LogLevel=ERROR "$control_plane" "$command"
}

printf '{"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"%s"},"data":{"bucket":"%s","namespace":"%s"}}\n' \
  "$configmap" "$bucket" "$storage_namespace" |
  remote_kubectl apply --server-side --field-manager rtgre-platform --filename -
echo "ConfigMap $configmap à jour dans $namespace : la prochaine sauvegarde part vers $bucket."
