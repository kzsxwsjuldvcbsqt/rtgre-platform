data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

# Bucket qui conserve le state de toutes les configurations Terraform du dépôt,
# y compris celui du bootstrap lui-même.
resource "oci_objectstorage_bucket" "terraform_state" {
  # checkov:skip=CKV_OCI_9:Chiffré par une clé gérée par Oracle ; le passage à une clé du Vault est suivi dans #44.
  compartment_id = oci_identity_compartment.platform.id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${var.project}-tfstate"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  # Émet un événement à chaque écriture ou suppression d'objet, pour pouvoir auditer le state.
  object_events_enabled = true
  freeform_tags         = local.freeform_tags

  lifecycle {
    # Le supprimer ferait perdre le state de toute la plateforme.
    prevent_destroy = true
  }
}
