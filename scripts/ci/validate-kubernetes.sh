#!/usr/bin/env bash
# Vérifie chaque chart de kubernetes/ : dépendances, helm lint, rendu, puis validation des
# objets rendus par kubeconform pour la version de Kubernetes du cluster.
#
#   scripts/ci/validate-kubernetes.sh
#
# Variable facultative :
#   KUBERNETES_VERSION   version visée (défaut : kubernetes_node_version de l'inventaire prod)
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
group_vars=$repo/ansible/inventories/prod/group_vars/all.yml
version=${KUBERNETES_VERSION:-$(sed -n 's/^kubernetes_node_version: "\(.*\)"$/\1/p' "$group_vars")}
: "${version:?kubernetes_node_version est introuvable dans $group_vars}"

# API que le cluster connaît en plus de celles de Kubernetes : certains charts ne rendent leurs
# objets (ServiceMonitor, par exemple) que si elles sont annoncées, comme le fait Argo CD.
api_versions=(
  --api-versions monitoring.coreos.com/v1
  --api-versions cert-manager.io/v1
  --api-versions gateway.networking.k8s.io/v1
)

for chart in "$repo"/kubernetes/*/; do
  name=$(basename "$chart")
  echo "== $name (Kubernetes $version)"
  helm dependency build "$chart" > /dev/null
  helm lint --quiet "$chart"
  # Les objets d'Argo CD (Application, AppProject) n'ont pas de schéma publié : ils sont comptés
  # comme ignorés, les autres sont validés strictement.
  helm template "$name" "$chart" --namespace "$name" --kube-version "$version" "${api_versions[@]}" |
    kubeconform -strict -summary -ignore-missing-schemas -kubernetes-version "$version"
done
