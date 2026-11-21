# Les clés d'API viennent de ~/.ovh.conf, jamais du dépôt. Elles sont limitées à la zone
# (README de ce dossier).
provider "ovh" {
  endpoint = var.ovh_endpoint
}
