# Quotas de la tenancy : une liste blanche de l'offre Always Free. Chaque famille est d'abord mise
# à zéro, puis seules les ressources gratuites sont autorisées, à hauteur de l'offre. Oracle évalue
# les instructions dans l'ordre et la dernière l'emporte : une création hors de ces limites est
# refusée, même avec un moyen de paiement enregistré. Voir l'ADR 0008.
resource "oci_limits_quota" "free_tier" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-free-tier"
  description    = "Limite la tenancy aux ressources de l'offre Always Free."
  freeform_tags  = local.freeform_tags

  statements = [
    "zero compute-core quotas in tenancy",
    "set compute-core quota standard-a1-core-count to ${var.free_tier_quotas.a1_ocpus} in tenancy",
    # Les ARM ont aussi une limite régionale, que le « zero » de la famille met à 0.
    "set compute-core quota standard-a1-core-regional-count to ${var.free_tier_quotas.a1_ocpus} in tenancy",
    "zero compute-memory quotas in tenancy",
    "set compute-memory quota standard-a1-memory-count to ${var.free_tier_quotas.a1_memory_in_gbs} in tenancy",
    "set compute-memory quota standard-a1-memory-regional-count to ${var.free_tier_quotas.a1_memory_in_gbs} in tenancy",
    "zero block-storage quotas in tenancy",
    "set block-storage quota total-storage-gb to ${var.free_tier_quotas.block_storage_in_gbs} in tenancy",
    "set block-storage quota backup-count to ${var.free_tier_quotas.block_backups} in tenancy",
    "set object-storage quota storage-bytes to ${var.free_tier_quotas.object_storage_in_bytes} in tenancy",
    "zero database quotas in tenancy",
  ]
}
