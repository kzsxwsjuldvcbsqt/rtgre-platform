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

  # Chiffre le trafic entre l'instance et son volume de démarrage. Dès qu'une option de lancement
  # est donnée, Oracle exige le type de réseau et n'applique plus celles de l'image : elles sont
  # donc toutes écrites, telles que l'image les pose.
  launch_options {
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    boot_volume_type                    = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
  }

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

  # Seul le service de métadonnées v2 (en-tête d'autorisation obligatoire) reste actif : le v1 peut
  # être exploité par une requête forgée depuis le nœud (SSRF) pour lire ses identifiants.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    dynamic "plugins_config" {
      for_each = var.agent_plugins

      content {
        name          = plugins_config.key
        desired_state = plugins_config.value
      }
    }
  }

  lifecycle {
    # L'image la plus récente change chaque mois : sans cela, chaque nouvelle image recréerait les nœuds.
    # Un nœud prend la nouvelle image quand il est volontairement remplacé : workflow Terraform lancé
    # à la main avec son nom (docs/runbooks/reconstruire-la-plateforme.md).
    ignore_changes = [source_details[0].source_id]
  }
}
