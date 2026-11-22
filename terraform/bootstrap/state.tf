data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

# Clé maîtresse qui chiffre le bucket du state, dans un Vault du compartiment (ADR 0020). Le
# Vault est du type par défaut, et la clé est protégée par logiciel : tous deux sont gratuits
# sans limite, alors qu'une clé protégée par HSM est facturée au-delà de vingt versions.
resource "oci_kms_vault" "state" {
  compartment_id = oci_identity_compartment.platform.id
  display_name   = "${var.project}-state"
  vault_type     = "DEFAULT"
  freeform_tags  = local.freeform_tags

  lifecycle {
    # Sans lui, la clé est perdue, et le state avec elle.
    prevent_destroy = true
  }
}

resource "oci_kms_key" "state" {
  compartment_id      = oci_identity_compartment.platform.id
  display_name        = "${var.project}-tfstate"
  management_endpoint = oci_kms_vault.state.management_endpoint
  protection_mode     = "SOFTWARE"
  freeform_tags       = local.freeform_tags

  key_shape {
    algorithm = "AES"
    length    = var.state_key_length
  }

  lifecycle {
    # La supprimer rendrait le state illisible, pour toujours.
    prevent_destroy = true
  }
}

# Object Storage chiffre et déchiffre au nom de qui lit ou écrit un objet : le service reçoit le
# droit d'utiliser cette clé, et aucune autre.
resource "oci_identity_policy" "state_encryption" {
  compartment_id = oci_identity_compartment.platform.id
  name           = "${var.project}-state-encryption"
  description    = "Laisse Object Storage chiffrer le bucket du state avec sa clé du Vault."
  freeform_tags  = local.freeform_tags

  statements = [
    join(" ", [
      "Allow service objectstorage-${var.region} to use keys",
      "in compartment ${oci_identity_compartment.platform.name}",
      "where target.key.id = '${oci_kms_key.state.id}'",
    ]),
  ]
}

# Une politique tout juste créée n'est pas appliquée aussitôt : sans ce délai, Oracle refuse
# d'associer la clé au bucket.
resource "time_sleep" "state_encryption_propagation" {
  create_duration = var.policy_propagation_delay

  triggers = {
    policy = oci_identity_policy.state_encryption.id
  }
}

# Bucket qui conserve le state de toutes les configurations Terraform du dépôt,
# y compris celui du bootstrap lui-même.
resource "oci_objectstorage_bucket" "terraform_state" {
  compartment_id = oci_identity_compartment.platform.id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${var.project}-tfstate"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  # Émet un événement à chaque écriture ou suppression d'objet, pour pouvoir auditer le state.
  object_events_enabled = true
  kms_key_id            = oci_kms_key.state.id
  freeform_tags         = local.freeform_tags

  depends_on = [time_sleep.state_encryption_propagation]

  lifecycle {
    # Le supprimer ferait perdre le state de toute la plateforme.
    prevent_destroy = true
  }
}
