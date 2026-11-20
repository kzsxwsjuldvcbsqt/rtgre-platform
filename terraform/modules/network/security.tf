# Groupes de sécurité réseau : sans règle d'entrée explicite, tout le trafic entrant est refusé.

resource "oci_core_network_security_group" "load_balancer" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name}-load-balancer"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_network_security_group" "nodes" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name}-nodes"
  freeform_tags  = var.freeform_tags
}

locals {
  public_ingress_rules = {
    for pair in setproduct(var.public_ingress_cidrs, var.public_ingress_ports) :
    "${pair[0]}:${pair[1]}" => { cidr = pair[0], port = pair[1] }
  }
}

# Load balancer : HTTP et HTTPS depuis les plages autorisées, et vers les nœuds uniquement.

resource "oci_core_network_security_group_security_rule" "load_balancer_ingress_public" {
  for_each = local.public_ingress_rules

  network_security_group_id = oci_core_network_security_group.load_balancer.id
  description               = "Trafic web vers le load balancer, port ${each.value.port}"
  direction                 = "INGRESS"
  protocol                  = local.protocol.tcp
  source_type               = "CIDR_BLOCK"
  source                    = each.value.cidr
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "load_balancer_egress_nodes" {
  network_security_group_id = oci_core_network_security_group.load_balancer.id
  description               = "Le load balancer ne parle qu'aux nœuds"
  direction                 = "EGRESS"
  protocol                  = local.protocol.tcp
  destination_type          = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.nodes.id
  stateless                 = false
}

# Nœuds : trafic libre entre nœuds (plan de contrôle, kubelet, CNI), trafic TCP depuis le
# load balancer, sortie libre pour les paquets et les images. Rien d'autre n'entre.

resource "oci_core_network_security_group_security_rule" "nodes_ingress_nodes" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  description               = "Trafic entre nœuds du cluster"
  direction                 = "INGRESS"
  protocol                  = local.protocol.all
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.nodes.id
  stateless                 = false
}

resource "oci_core_network_security_group_security_rule" "nodes_ingress_load_balancer" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  description               = "Trafic du load balancer vers les nœuds"
  direction                 = "INGRESS"
  protocol                  = local.protocol.tcp
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.load_balancer.id
  stateless                 = false
}

# Messages ICMP « fragmentation nécessaire » : sans eux, la découverte du MTU échoue et
# certaines connexions restent bloquées.
resource "oci_core_network_security_group_security_rule" "nodes_ingress_path_mtu" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  description               = "Découverte du MTU (ICMP type 3, code 4)"
  direction                 = "INGRESS"
  protocol                  = local.protocol.icmp
  source_type               = "CIDR_BLOCK"
  source                    = local.anywhere
  stateless                 = false

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "nodes_egress_anywhere" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  description               = "Sortie des nœuds : paquets, images de conteneurs, API Oracle"
  direction                 = "EGRESS"
  protocol                  = local.protocol.all
  destination_type          = "CIDR_BLOCK"
  destination               = local.anywhere
  stateless                 = false
}
