locals {
  compartment_name = "${var.project}-${var.environment}"

  # Tags appliqués d'office à toute ressource créée dans le compartiment.
  default_tags = {
    project     = var.project
    environment = var.environment
  }

  freeform_tags = {
    managed-by = "terraform"
    stack      = "bootstrap"
  }
}

resource "oci_identity_tag_namespace" "platform" {
  compartment_id = var.tenancy_ocid
  name           = var.project
  description    = "Tags des ressources de ${var.project}."
  freeform_tags  = local.freeform_tags
}

resource "oci_identity_tag" "default" {
  for_each = local.default_tags

  tag_namespace_id = oci_identity_tag_namespace.platform.id
  name             = each.key
  description      = "Valeur de ${each.key} propre à ${var.project}."
  freeform_tags    = local.freeform_tags
}

# Un tag tout juste créé est refusé (400 « Invalid tags ») tant qu'Oracle ne l'a pas propagé.
resource "time_sleep" "tag_propagation" {
  create_duration = var.tag_propagation_delay

  triggers = {
    for key, tag in oci_identity_tag.default : key => tag.id
  }
}

resource "oci_identity_compartment" "platform" {
  compartment_id = var.tenancy_ocid
  name           = local.compartment_name
  description    = var.compartment_description
  enable_delete  = true
  freeform_tags  = local.freeform_tags

  defined_tags = {
    for key, value in local.default_tags :
    "${oci_identity_tag_namespace.platform.name}.${oci_identity_tag.default[key].name}" => value
  }

  depends_on = [time_sleep.tag_propagation]

  lifecycle {
    # Oracle ajoute ces tags à la création : les retirer ferait apparaître un écart à chaque plan.
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

resource "oci_identity_tag_default" "platform" {
  for_each = local.default_tags

  compartment_id    = oci_identity_compartment.platform.id
  tag_definition_id = oci_identity_tag.default[each.key].id
  value             = each.value
  is_required       = false
}
