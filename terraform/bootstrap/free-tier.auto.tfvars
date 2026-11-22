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
  # Le Vault lui-même n'est pas compté par l'offre : seules les versions de clé protégées par
  # HSM le sont. Un seul suffit, pour la clé du state.
  vaults = 1
  # Courrier : 3000 messages gratuits par mois, soit 100 par jour sur un mois de 30 jours. Un
  # seul expéditeur suffit, pour les alertes.
  mail_senders  = 1
  mails_per_day = 100
  # Notifications : 1000 courriers gratuits par mois. Un seul sujet, celui des pannes.
  notification_topics = 1
}
