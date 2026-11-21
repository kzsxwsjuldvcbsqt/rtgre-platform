#!/usr/bin/env bash
# Liste les images que déploient les charts de kubernetes/, une par ligne : celles des champs
# « image », et celles qu'un contrôleur reçoit en argument pour les lancer lui-même. Les images
# citées sans jamais être lancées sont écartées par kubernetes/unused-images.txt.
#
#   scripts/ci/list-chart-images.sh
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
unused=$repo/kubernetes/unused-images.txt

for chart in "$repo"/kubernetes/*/; do
  helm dependency build "$chart" > /dev/null
  # Mêmes API que scripts/ci/validate-kubernetes.sh : le rendu doit être celui du cluster.
  helm template "$(basename "$chart")" "$chart" --api-versions monitoring.coreos.com/v1 \
    --api-versions cert-manager.io/v1 --api-versions gateway.networking.k8s.io/v1
done |
  sed -n \
    -e 's/^ *\(- \)\{0,1\}image: *"\{0,1\}\([^" ]*\)"\{0,1\} *$/\2/p' \
    -e 's/^ *- --[a-z0-9-]*=\([a-z0-9.-]*\.[a-z]*\/[a-z0-9._\/-]*:[A-Za-z0-9._@:-]*\)$/\1/p' |
  sort --unique |
  while read -r image; do
    name=${image%%@*}
    name=${name%:*}
    grep --quiet --line-regexp --fixed-strings "$name" "$unused" || echo "$image"
  done
