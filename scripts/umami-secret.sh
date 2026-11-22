#!/usr/bin/env bash
# Crée le Secret d'Umami : le mot de passe de sa base et la clé qui signe les sessions de son
# tableau de bord. Les deux sont tirés au hasard sur le poste, et ne sont ni affichés, ni passés
# en argument d'une commande, ni écrits sur un nœud.
#
#   scripts/bastion-ssh-config.sh
#   scripts/umami-secret.sh
#
# Si le Secret existe, le script ne fait rien : la base est initialisée avec son mot de passe,
# et un autre l'en couperait.
#
# Variable facultative :
#   RTGRE_SSH_CONFIG   configuration SSH (défaut : ansible/.ssh/bastion.conf)
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
config=${RTGRE_SSH_CONFIG:-$repo/ansible/.ssh/bastion.conf}
values=$repo/kubernetes/umami/values.yaml

namespace=$(awk '/^  umami:/ { found = 1; next } found && $1 == "namespace:" { print $2; exit }' \
  "$repo/kubernetes/apps/values.yaml")
secret=$(sed -n 's/^secretName: //p' "$values")
: "${namespace:?espace de noms umami introuvable dans kubernetes/apps/values.yaml}"
: "${secret:?secretName est introuvable dans $values}"

# Premier hôte de la configuration du Bastion dont le nom commence par cp-.
control_plane=$(awk '$1 == "Host" { for (i = 2; i <= NF; i++) if ($i ~ /^cp-/) { print $i; exit } }' "$config")

# ssh recolle ses arguments avant de les passer au shell du nœud : chacun est protégé d'abord.
remote_kubectl() {
  local command
  command=$(printf '%q ' kubectl --namespace "$namespace" "$@")
  ssh -F "$config" -o BatchMode=yes -o LogLevel=ERROR "$control_plane" "$command"
}

if remote_kubectl get secret "$secret" --output name > /dev/null 2>&1; then
  echo "Le Secret $secret existe déjà dans $namespace : rien à faire."
  exit 0
fi

# Des valeurs hexadécimales : le mot de passe entre tel quel dans l'adresse de la base.
# Appliqué côté serveur : kubectl ne recopie pas le Secret dans une annotation.
printf '{"apiVersion":"v1","kind":"Secret","metadata":{"name":"%s"},"stringData":{"postgres-password":"%s","app-secret":"%s"}}\n' \
  "$secret" "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" |
  remote_kubectl apply --server-side --field-manager rtgre-platform --filename -
echo "Secret $secret créé dans $namespace : les pods d'Umami démarrent dans la minute."
