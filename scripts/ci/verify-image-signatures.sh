#!/usr/bin/env bash
# Vérifie les images des charts de kubernetes/ qui doivent être signées : chacune doit être
# référencée par son empreinte et porter une signature cosign de l'identité attendue. Une
# image construite ailleurs que par son workflow officiel ne peut donc pas être déployée.
#
#   scripts/ci/verify-image-signatures.sh
#
# Les images concernées et leurs signataires sont listés dans
# kubernetes/kyverno/files/signed-images.txt, que Kyverno applique aussi dans le cluster.
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
policy=$repo/kubernetes/kyverno/files/signed-images.txt

images=$("$repo/scripts/ci/list-chart-images.sh")

# Retire les espaces autour d'un champ du fichier.
trim() {
  local value=$1
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

status=0
checked=0
while IFS='|' read -r prefix identity issuer; do
  prefix=$(trim "$prefix")
  case "$prefix" in '' | '#'*) continue ;; esac
  identity=$(trim "$identity")
  issuer=$(trim "$issuer")
  for image in $images; do
    case "$image" in "$prefix":* | "$prefix"@*) ;; *) continue ;; esac
    checked=$((checked + 1))
    case "$image" in
      *@sha256:*) ;;
      *)
        echo "ÉCHEC  $image : pas d'empreinte, la signature ne garantirait rien."
        status=1
        continue
        ;;
    esac
    # cosign vérifie l'empreinte : le tag éventuel est retiré.
    reference="${image%%:*}@${image##*@}"
    if cosign verify "$reference" --certificate-identity "$identity" \
      --certificate-oidc-issuer "$issuer" > /dev/null 2>&1; then
      echo "OK     $image"
    else
      echo "ÉCHEC  $image : aucune signature de $identity."
      status=1
    fi
  done
done < "$policy"

echo "$checked image(s) à signature exigée, sur $(echo "$images" | wc -l) image(s) déployée(s)."
exit "$status"
