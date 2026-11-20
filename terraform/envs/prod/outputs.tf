output "compartment_id" {
  description = "OCID du compartiment de la plateforme, lu dans le state du bootstrap."
  value       = local.compartment_id
}

output "tag_namespace" {
  description = "Espace de noms des tags définis, lu dans le state du bootstrap."
  value       = local.tag_namespace
}

output "freeform_tags" {
  description = "Tags libres appliqués aux ressources de cette configuration."
  value       = local.freeform_tags
}

output "network" {
  description = "Identifiants du réseau : réseau virtuel, sous-réseaux et groupes de sécurité par rôle."
  value = {
    vcn_id       = module.network.vcn_id
    subnet_ids   = module.network.subnet_ids
    subnet_cidrs = module.network.subnet_cidrs
    nsg_ids      = module.network.nsg_ids
  }
}
