# Sauvegardes de la plateforme, hors du cluster (ADR 0026) : un bucket privé, chiffré par sa
# propre clé du Vault, où les nœuds ne peuvent que déposer. Ils n'y lisent rien, n'y remplacent
# rien et n'y suppriment rien : Object Storage purge lui-même les sauvegardes anciennes.

locals {
  backup_bucket_name = "${var.project}-backups"
}

resource "oci_kms_key" "backups" {
  compartment_id      = oci_identity_compartment.platform.id
  display_name        = local.backup_bucket_name
  management_endpoint = oci_kms_vault.state.management_endpoint
  protection_mode     = "SOFTWARE"
  freeform_tags       = local.freeform_tags

  key_shape {
    algorithm = "AES"
    length    = var.state_key_length
  }

  lifecycle {
    # La supprimer rendrait les sauvegardes illisibles, pour toujours.
    prevent_destroy = true
  }
}

# Object Storage chiffre le bucket avec sa clé, et y supprime les objets que la règle de
# conservation désigne. Il n'a de droit sur aucun autre bucket.
resource "oci_identity_policy" "backup_storage" {
  compartment_id = oci_identity_compartment.platform.id
  name           = "${var.project}-backup-storage"
  description    = "Laisse Object Storage chiffrer le bucket des sauvegardes et y appliquer la conservation."
  freeform_tags  = local.freeform_tags

  statements = [
    join(" ", [
      "Allow service objectstorage-${var.region} to use keys",
      "in compartment ${oci_identity_compartment.platform.name}",
      "where target.key.id = '${oci_kms_key.backups.id}'",
    ]),
    join(" ", [
      "Allow service objectstorage-${var.region} to manage object-family",
      "in compartment ${oci_identity_compartment.platform.name}",
      "where target.bucket.name = '${local.backup_bucket_name}'",
    ]),
  ]
}

resource "time_sleep" "backup_storage_propagation" {
  create_duration = var.policy_propagation_delay

  triggers = {
    policy = oci_identity_policy.backup_storage.id
  }
}

resource "oci_objectstorage_bucket" "backups" {
  # checkov:skip=CKV_OCI_8:Sans versions : chaque sauvegarde est un objet de plus, que les nœuds ne peuvent ni remplacer ni supprimer, et une version garderait ce que la conservation doit effacer.
  compartment_id        = oci_identity_compartment.platform.id
  namespace             = data.oci_objectstorage_namespace.this.namespace
  name                  = local.backup_bucket_name
  access_type           = "NoPublicAccess"
  storage_tier          = "Standard"
  versioning            = "Disabled"
  object_events_enabled = true
  kms_key_id            = oci_kms_key.backups.id
  freeform_tags         = local.freeform_tags

  depends_on = [time_sleep.backup_storage_propagation]

  lifecycle {
    # Le supprimer ferait perdre toutes les sauvegardes.
    prevent_destroy = true
  }
}

resource "oci_objectstorage_object_lifecycle_policy" "backups" {
  namespace = data.oci_objectstorage_namespace.this.namespace
  bucket    = oci_objectstorage_bucket.backups.name

  rules {
    name        = "expire-backups"
    action      = "DELETE"
    target      = "objects"
    time_amount = var.backups.retention_days
    time_unit   = "DAYS"
    is_enabled  = true
  }

  # Un dépôt en plusieurs parties resté inachevé occupe de la place sans apparaître dans le bucket.
  rules {
    name        = "abort-unfinished-uploads"
    action      = "ABORT"
    target      = "multipart-uploads"
    time_amount = var.backups.unfinished_upload_days
    time_unit   = "DAYS"
    is_enabled  = true
  }
}

# Identité des nœuds : toute instance du compartiment. Un pod de sauvegarde l'obtient du service
# de métadonnées de son nœud, sans qu'aucun secret ne soit déposé dans le cluster.
resource "oci_identity_domains_dynamic_resource_group" "nodes" {
  idcs_endpoint = local.identity_domain_url
  display_name  = "${var.project}-nodes"
  description   = "Instances de la plateforme, pour le dépôt des sauvegardes."
  matching_rule = "ALL {instance.compartment.id = '${oci_identity_compartment.platform.id}'}"
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:DynamicResourceGroup"]

  lifecycle {
    # Oracle ajoute à « schemas » des extensions (OCITags…) selon les attributs renvoyés : les
    # retirer à chaque plan n'aurait aucun effet.
    ignore_changes = [schemas]
  }
}

# Les nœuds déposent des objets dans ce seul bucket et en voient la liste. Ni lecture, ni
# remplacement, ni suppression : un nœud compromis ne peut ni lire ni détruire les sauvegardes.
resource "oci_identity_policy" "backup_deposit" {
  compartment_id = oci_identity_compartment.platform.id
  name           = "${var.project}-backup-deposit"
  description    = "Laisse les noeuds déposer des sauvegardes, sans les lire ni les supprimer."
  freeform_tags  = local.freeform_tags

  statements = [
    join(" ", [
      "Allow dynamic-group '${var.identity_domain_name}'/'${oci_identity_domains_dynamic_resource_group.nodes.display_name}'",
      "to manage objects in compartment ${oci_identity_compartment.platform.name}",
      "where all {target.bucket.name = '${local.backup_bucket_name}',",
      "any {request.permission = 'OBJECT_CREATE', request.permission = 'OBJECT_INSPECT'}}",
    ]),
  ]

  lifecycle {
    # Oracle remplace le nom du groupe par son identifiant à l'écriture de la politique : si le
    # groupe est recréé, elle désigne un groupe qui n'existe plus.
    replace_triggered_by = [oci_identity_domains_dynamic_resource_group.nodes]
  }
}
