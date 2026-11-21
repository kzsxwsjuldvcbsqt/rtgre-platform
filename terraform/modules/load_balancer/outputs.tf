output "id" {
  description = "OCID du load balancer."
  value       = oci_network_load_balancer_network_load_balancer.this.id
}

output "public_ip" {
  description = "Adresse IPv4 publique du load balancer : celle que le DNS doit désigner."
  value = one([
    for address in oci_network_load_balancer_network_load_balancer.this.ip_addresses :
    address.ip_address if address.is_public && address.ip_version == "IPV4"
  ])
}

output "private_ip" {
  description = "Adresse privée du load balancer : celle que voient les instances."
  value = one([
    for address in oci_network_load_balancer_network_load_balancer.this.ip_addresses :
    address.ip_address if !address.is_public && address.ip_version == "IPV4"
  ])
}

output "listeners" {
  description = "Ports écoutés, par nom : le port public et le port des instances."
  value       = var.listeners
}
