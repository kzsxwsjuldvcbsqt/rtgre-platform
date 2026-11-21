# Le service Bastion d'Oracle ouvre des sessions SSH temporaires vers les nœuds, sans aucun port
# exposé sur Internet (ADR 0006). Il est gratuit.
resource "oci_bastion_bastion" "this" {
  compartment_id = var.compartment_id
  name           = var.name
  # En majuscules, comme l'API le renvoie : en minuscules, chaque plan recréait le Bastion.
  bastion_type                 = "STANDARD"
  target_subnet_id             = var.target_subnet_id
  client_cidr_block_allow_list = var.client_cidr_block_allow_list
  max_session_ttl_in_seconds   = var.max_session_ttl_in_seconds
  freeform_tags                = var.freeform_tags
}

# SSH n'entre sur les nœuds que depuis le point d'accès privé du Bastion.
resource "oci_core_network_security_group_security_rule" "nodes_ingress_ssh_from_bastion" {
  # checkov:skip=CKV_OCI_21:Règles avec état voulues : une règle sans état exige d'écrire aussi la règle de retour, source d'erreurs.
  network_security_group_id = var.target_nsg_id
  description               = "SSH depuis le Bastion uniquement"
  direction                 = "INGRESS"
  protocol                  = "6"
  source_type               = "CIDR_BLOCK"
  source                    = "${oci_bastion_bastion.this.private_endpoint_ip_address}/32"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = var.ssh_port
      max = var.ssh_port
    }
  }
}
