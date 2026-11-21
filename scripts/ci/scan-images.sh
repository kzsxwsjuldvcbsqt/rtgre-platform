#!/usr/bin/env bash
# Analyse avec Trivy chaque image que déploient les charts de kubernetes/. Une vulnérabilité
# HIGH ou CRITICAL fait échouer l'analyse, sauf exception justifiée et datée dans
# .trivyignore.yaml.
#
#   scripts/ci/scan-images.sh
#
# Variable facultative :
#   IMAGE_PLATFORM   plateforme analysée (défaut : linux/arm64, celle des nœuds)
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
platform=${IMAGE_PLATFORM:-linux/arm64}

images=$("$repo/scripts/ci/list-chart-images.sh")
failed=0
count=0
for image in $images; do
  count=$((count + 1))
  echo "== $image"
  # trivy.yaml écarte des dossiers du dépôt, qui n'ont pas de sens dans une image : les réglages
  # sont donc passés ici.
  if ! trivy image --config /dev/null --platform "$platform" --scanners vuln --severity HIGH,CRITICAL \
    --exit-code 1 --ignorefile "$repo/.trivyignore.yaml" --quiet "$image"; then
    failed=$((failed + 1))
  fi
done

echo "$count images analysées, $failed en échec."
[ "$count" -gt 0 ] && [ "$failed" -eq 0 ]
