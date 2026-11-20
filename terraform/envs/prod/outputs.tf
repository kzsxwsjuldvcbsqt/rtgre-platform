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
