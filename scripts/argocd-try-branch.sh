#!/usr/bin/env bash
# Fait suivre une branche à Argo CD, le temps de l'essayer sur le cluster avant de la fusionner,
# puis revient à la révision du dépôt.
#
#   scripts/bastion-ssh-config.sh
#   scripts/argocd-try-branch.sh feat/ma-branche   # essaie la branche, déjà poussée
#   scripts/argocd-try-branch.sh                   # revient à la révision de kubernetes/apps/values.yaml
#
# Le chart kubernetes/apps est rendu depuis la copie de travail : se placer sur la branche pour
# l'essayer, et sur la branche principale à jour pour revenir.
#
# Variable facultative :
#   RTGRE_SSH_CONFIG   configuration SSH (défaut : ansible/.ssh/bastion.conf)
set -euo pipefail

branch=${1:-}
repo=$(git rev-parse --show-toplevel)
config=${RTGRE_SSH_CONFIG:-$repo/ansible/.ssh/bastion.conf}
chart=$repo/kubernetes/apps
namespace=$(sed -n 's/^argocdNamespace: //p' "$chart/values.yaml")
: "${namespace:?argocdNamespace est introuvable dans $chart/values.yaml}"

# kubectl lit son entrée standard sur le plan de contrôle : rien n'est écrit sur le nœud.
remote_kubectl() {
  ssh -F "$config" -o BatchMode=yes -o LogLevel=ERROR "$(control_plane)" kubectl --namespace "$namespace" "$@"
}

# Premier hôte de la configuration du Bastion dont le nom commence par cp-.
control_plane() {
  awk '$1 == "Host" { for (i = 2; i <= NF; i++) if ($i ~ /^cp-/) { print $i; exit } }' "$config"
}

if [ -n "$branch" ]; then
  if ! git ls-remote --exit-code --heads origin "$branch" > /dev/null; then
    echo "La branche $branch n'existe pas sur origin : la pousser d'abord." >&2
    exit 1
  fi
  # L'application racine cesse de se synchroniser : sinon elle annulerait l'essai aussitôt.
  echo '{"spec":{"syncPolicy":{"automated":null}}}' |
    remote_kubectl patch applications.argoproj.io root --type merge --patch-file /dev/stdin
  # Projets et applications suivent la branche ; l'application racine reste sur sa révision.
  helm template root "$chart" --namespace "$namespace" --set "repository.revision=$branch" \
    --show-only templates/projects.yaml --show-only templates/applications.yaml |
    remote_kubectl apply --filename -
  echo "Argo CD suit $branch. Pour revenir : $0"
else
  # Tout le chart, application racine comprise : elle reprend sa synchronisation automatique.
  helm template root "$chart" --namespace "$namespace" | remote_kubectl apply --filename -
  echo "Argo CD suit de nouveau la révision du dépôt."
fi
