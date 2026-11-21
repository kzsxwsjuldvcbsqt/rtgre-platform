# Rôle `cilium`

Installe ou met à jour le CNI Cilium, depuis le plan de contrôle ([ADR 0009](../../../docs/adr/0009-reseau-des-pods-avec-cilium.md)).

1. Le chart de version `cilium_chart_version` est rendu par `helm template` sur le poste de contrôle, avec les valeurs `cilium_values`. Helm est fourni par `mise.toml`.
2. Le manifeste est copié sur le plan de contrôle, puis comparé au cluster avec `kubectl diff`.
3. Il n'est appliqué (`kubectl apply --server-side`) qu'en cas d'écart, puis le rôle attend que les agents soient prêts.

## Choix notables

- **IPAM `kubernetes`** : la plage par défaut de Cilium (`10.0.0.0/8`) chevaucherait le réseau virtuel.
- **Certificats générés dans le cluster** (`hubble.tls.auto.method: cronJob`) : avec la méthode par défaut, chaque rendu du chart contient une nouvelle CA, et chaque passage l'aurait remplacée.
- **Première installation** : `kubectl diff` ne peut pas simuler des objets dans un espace de noms que le manifeste crée lui-même (`NotFound`). Ce cas est traité comme un écart à appliquer.
