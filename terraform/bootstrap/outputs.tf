output "compartment_id" {
  description = "OCID du compartiment qui accueille toutes les ressources de la plateforme."
  value       = oci_identity_compartment.platform.id
}

output "compartment_name" {
  description = "Nom du compartiment de la plateforme."
  value       = oci_identity_compartment.platform.name
}

output "budget_id" {
  description = "OCID du budget mensuel de la tenancy."
  value       = oci_budget_budget.tenancy.id
}

output "tag_namespace" {
  description = "Espace de noms des tags définis de la plateforme."
  value       = oci_identity_tag_namespace.platform.name
}
