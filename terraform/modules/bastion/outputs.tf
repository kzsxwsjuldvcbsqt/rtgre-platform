output "bastion_id" {
  description = "OCID du Bastion, pour créer des sessions."
  value       = oci_bastion_bastion.this.id
}

output "private_endpoint_ip_address" {
  description = "Adresse privée du Bastion dans le sous-réseau des nœuds."
  value       = oci_bastion_bastion.this.private_endpoint_ip_address
}

output "max_session_ttl_in_seconds" {
  description = "Durée de vie maximale d'une session."
  value       = oci_bastion_bastion.this.max_session_ttl_in_seconds
}
