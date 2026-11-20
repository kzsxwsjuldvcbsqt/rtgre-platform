output "compartment_id" {
  description = "OCID du compartiment qui accueille toutes les ressources de la plateforme."
  value       = oci_identity_compartment.platform.id
}

output "compartment_name" {
  description = "Nom du compartiment de la plateforme."
  value       = oci_identity_compartment.platform.name
}

output "tag_namespace" {
  description = "Espace de noms des tags définis de la plateforme."
  value       = oci_identity_tag_namespace.platform.name
}
