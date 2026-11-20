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

output "state_bucket" {
  description = "Bucket Object Storage qui conserve les states Terraform."
  value       = oci_objectstorage_bucket.terraform_state.name
}

output "objectstorage_namespace" {
  description = "Namespace Object Storage de la tenancy, à reporter dans les fichiers backend.hcl."
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "tag_namespace" {
  description = "Espace de noms des tags définis de la plateforme."
  value       = oci_identity_tag_namespace.platform.name
}
