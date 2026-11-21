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

output "nodes" {
  description = "Nœuds du cluster : OCID, rôle, domaine de panne et adresses."
  value       = module.compute.nodes
}

output "node_image" {
  description = "Image utilisée pour les nouveaux nœuds."
  value       = module.compute.image
}

output "load_balancer" {
  description = "Load balancer web : OCID, adresses publique et privée, ports écoutés."
  value = {
    id         = module.load_balancer.id
    public_ip  = module.load_balancer.public_ip
    private_ip = module.load_balancer.private_ip
    listeners  = module.load_balancer.listeners
  }
}

output "bastion" {
  description = "Bastion des nœuds : OCID et durée maximale d'une session."
  value = {
    id                         = module.bastion.bastion_id
    max_session_ttl_in_seconds = module.bastion.max_session_ttl_in_seconds
  }
}
