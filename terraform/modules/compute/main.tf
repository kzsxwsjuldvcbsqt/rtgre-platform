data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_id
}

locals {
  # La région de Paris n'a qu'un domaine de disponibilité ; les nœuds sont répartis entre ses
  # domaines de panne pour ne pas tomber ensemble lors d'une maintenance matérielle.
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
}

data "oci_identity_fault_domains" "this" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
}

data "oci_core_images" "this" {
  compartment_id           = var.compartment_id
  operating_system         = var.image_operating_system
  operating_system_version = var.image_operating_system_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  fault_domains = [for fault_domain in data.oci_identity_fault_domains.this.fault_domains : fault_domain.name]
  node_names    = sort(keys(var.nodes))

  fault_domain_by_node = {
    for index, hostname in local.node_names : hostname => local.fault_domains[index % length(local.fault_domains)]
  }

  latest_image_id = data.oci_core_images.this.images[0].id
}

resource "oci_core_instance" "node" {
  for_each = var.nodes

  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  fault_domain        = local.fault_domain_by_node[each.key]
  display_name        = "${var.name}-${each.key}"
  shape               = var.shape

  freeform_tags = merge(var.freeform_tags, {
    kubernetes-role = each.value.role
  })

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = local.latest_image_id
    boot_volume_size_in_gbs = each.value.boot_volume_size_in_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = var.nsg_ids
    hostname_label   = each.key
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = join("\n", var.ssh_authorized_keys)
  }

  lifecycle {
    # L'image la plus récente change chaque mois : sans cela, chaque nouvelle image recréerait les nœuds.
    # Un nœud prend la nouvelle image quand il est volontairement remplacé (terraform apply -replace).
    ignore_changes = [source_details[0].source_id]
  }
}
