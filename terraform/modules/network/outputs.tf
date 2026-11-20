output "vcn_id" {
  description = "OCID du réseau virtuel."
  value       = oci_core_vcn.this.id
}

output "vcn_cidr" {
  description = "Plage d'adresses du réseau virtuel."
  value       = var.vcn_cidr
}

output "subnet_ids" {
  description = "OCID de chaque sous-réseau, par rôle (load_balancer, nodes)."
  value       = { for role, subnet in oci_core_subnet.this : role => subnet.id }
}

output "subnet_cidrs" {
  description = "Plage d'adresses de chaque sous-réseau, par rôle."
  value       = local.subnet_cidrs
}

output "nsg_ids" {
  description = "OCID de chaque groupe de sécurité réseau, par rôle (load_balancer, nodes)."
  value = {
    load_balancer = oci_core_network_security_group.load_balancer.id
    nodes         = oci_core_network_security_group.nodes.id
  }
}
