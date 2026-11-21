# Limites de l'offre Always Free, appliquées en quotas à toute la tenancy (ADR 0008).
# Relevées le 2026-11-21 sur https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm
# Ampere A1 : 2 OCPU et 12 Go depuis le 15 juin 2026.
free_tier_quotas = {
  a1_ocpus                = 2
  a1_memory_in_gbs        = 12
  block_storage_in_gbs    = 200
  block_backups           = 5
  object_storage_in_bytes = 20000000000
  network_load_balancers  = 1
}
