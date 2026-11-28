#!/usr/bin/env bash
# Aligne les images à signature exigée sur ce que publie leur registre : pour chacune, l'empreinte
# que porte aujourd'hui son tag remplace celle des valeurs des charts, à condition d'être signée
# par l'identité attendue. Rien n'est proposé, poussé ni fusionné ici : le script ne modifie que
# la copie de travail, et le workflow « Promote » fait le reste.
#
#   scripts/ci/promote-signed-images.sh
#
# Les images concernées et leurs signataires sont listés dans
# kubernetes/kyverno/files/signed-images.txt. Une image référencée sans tag ne suit rien : elle
# est laissée telle quelle.
#
# Dans un workflow, le script écrit dans $GITHUB_OUTPUT :
#   changed   true si une empreinte a changé
#   summary   les images mises à jour, pour le titre du commit (« dépôt/image vers 58f0ab1 »)
#   slug      les mêmes, pour le nom de la branche (« image-58f0ab1 »)
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
policy=$repo/kubernetes/kyverno/files/signed-images.txt
# Longueur de l'empreinte abrégée, celle des titres de commit.
short_length=7

images=$("$repo/scripts/ci/list-chart-images.sh")

# Retire les espaces autour d'un champ du fichier.
trim() {
  local value=$1
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

summary=()
slug=()
while IFS='|' read -r prefix identity issuer; do
  prefix=$(trim "$prefix")
  case "$prefix" in '' | '#'*) continue ;; esac
  identity=$(trim "$identity")
  issuer=$(trim "$issuer")
  for image in $images; do
    case "$image" in "$prefix":*@sha256:*) ;; *) continue ;; esac
    current=${image##*@}
    tag=${image#"$prefix":}
    tag=${tag%@*}

    # cosign résout le tag et vérifie la signature de l'empreinte obtenue, en une seule lecture du
    # registre : l'empreinte retenue est celle qui a été vérifiée.
    if ! verified=$(cosign verify "$prefix:$tag" --certificate-identity "$identity" \
      --certificate-oidc-issuer "$issuer" 2> /dev/null); then
      echo "ÉCHEC       $prefix:$tag : aucune signature de $identity." >&2
      exit 1
    fi
    published=$(jq --raw-output '.[0].critical.image."docker-manifest-digest"' <<< "$verified")
    if ! [[ $published =~ ^sha256:[a-f0-9]{64}$ ]]; then
      echo "ÉCHEC       $prefix:$tag : empreinte illisible dans la réponse de cosign." >&2
      exit 1
    fi

    if [ "$published" = "$current" ]; then
      echo "À JOUR      $image"
      continue
    fi

    # L'empreinte en place n'existe que là où cette image est référencée.
    mapfile -t files < <(grep --files-with-matches --fixed-strings "$current" "$repo"/kubernetes/*/values.yaml)
    if [ "${#files[@]}" -eq 0 ]; then
      echo "ÉCHEC       $image : empreinte introuvable dans les valeurs des charts." >&2
      exit 1
    fi
    sed --in-place "s/$current/$published/g" "${files[@]}"

    short=${published#sha256:}
    short=${short:0:short_length}
    echo "MISE À JOUR $prefix:$tag : ${current#sha256:} -> ${published#sha256:}"
    summary+=("$prefix vers $short")
    slug+=("${prefix##*/}-$short")
  done
done < "$policy"

changed=false
if [ "${#summary[@]}" -gt 0 ]; then
  changed=true
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "changed=$changed"
    # Plusieurs images dans une même promotion : « a vers 1234567, b vers 89abcde ».
    echo "summary=$(printf '%s\n' "${summary[@]}" | paste --serial --delimiters=',' | sed 's/,/, /g')"
    echo "slug=$(printf '%s\n' "${slug[@]}" | paste --serial --delimiters='-')"
  } >> "$GITHUB_OUTPUT"
fi

echo "${#summary[@]} image(s) mise(s) à jour."
