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

output "identity_domain_url" {
  description = "URL du domaine d'identité, point d'entrée de l'échange de jeton."
  value       = local.identity_domain_url
}

output "ci_token_exchange_client_id" {
  description = "Identifiant de l'application OAuth qui authentifie l'échange de jeton de la CI."
  value       = oci_identity_domains_app.ci_token_exchange.name
}

output "ci_token_exchange_client_secret" {
  description = "Secret de l'application OAuth de la CI, à déposer dans les secrets GitHub."
  value       = oci_identity_domains_app.ci_token_exchange.client_secret
  sensitive   = true
}
