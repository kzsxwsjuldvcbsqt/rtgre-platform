locals {
  subnet_cidrs = {
    for role, netnum in var.subnet_netnums : role => cidrsubnet(var.vcn_cidr, var.subnet_newbits, netnum)
  }

  subnet_dns_labels = {
    load_balancer = "lb"
    nodes         = "nodes"
  }

  anywhere = "0.0.0.0/0"

  # Numéros de protocole attendus par l'API Oracle.
  protocol = {
    all  = "all"
    icmp = "1"
    tcp  = "6"
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.name}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = var.vcn_dns_label
  freeform_tags  = var.freeform_tags
}

# Les nœuds sortent par la passerelle Internet : l'offre Always Free ne fournit ni passerelle NAT
# ni passerelle de service (voir l'ADR 0006).
resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name}-igw"
  enabled        = true
  freeform_tags  = var.freeform_tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name}-public"
  freeform_tags  = var.freeform_tags

  route_rules {
    destination       = local.anywhere
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

# La liste de sécurité par défaut d'Oracle ouvre SSH à tout Internet. Elle est vidée :
# tout le filtrage passe par les groupes de sécurité réseau, rôle par rôle.
#
# Seule exception : le point d'accès privé du service Bastion vit dans le sous-réseau des nœuds
# sans NSG à lui, donc seule cette liste peut autoriser sa sortie vers le port SSH des nœuds.
resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id
  display_name               = "${var.name}-default-deny"
  freeform_tags              = var.freeform_tags

  dynamic "egress_security_rules" {
    for_each = var.nodes_subnet_ssh_egress_port == null ? [] : [var.nodes_subnet_ssh_egress_port]

    content {
      description      = "Sortie SSH vers les nœuds, pour le point d'accès du Bastion"
      destination      = local.subnet_cidrs["nodes"]
      destination_type = "CIDR_BLOCK"
      protocol         = local.protocol.tcp
      stateless        = false

      tcp_options {
        min = egress_security_rules.value
        max = egress_security_rules.value
      }
    }
  }
}

resource "oci_core_subnet" "this" {
  for_each = local.subnet_cidrs

  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${var.name}-${each.key}"
  cidr_block                 = each.value
  dns_label                  = local.subnet_dns_labels[each.key]
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_default_security_list.this.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.freeform_tags
}
