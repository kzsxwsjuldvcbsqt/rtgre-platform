output "nodes" {
  description = "Nœuds créés, par nom d'hôte : OCID, rôle, domaine de panne, adresses privée et publique."
  value = {
    for hostname, instance in oci_core_instance.node : hostname => {
      id           = instance.id
      role         = var.nodes[hostname].role
      fault_domain = instance.fault_domain
      private_ip   = instance.private_ip
      public_ip    = instance.public_ip
    }
  }
}

output "image" {
  description = "Image la plus récente correspondant aux filtres, utilisée pour les nouveaux nœuds."
  value = {
    id   = local.latest_image_id
    name = data.oci_core_images.this.images[0].display_name
  }
}
