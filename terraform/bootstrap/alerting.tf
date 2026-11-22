# Courrier des alertes : Alertmanager envoie par le service Email Delivery d'Oracle, avec un
# identifiant SMTP propre à un utilisateur de service qui n'a que ce droit (ADR 0021).

# Domaine d'envoi, distinct de celui du courrier ordinaire : sa réputation et ses
# enregistrements DNS (terraform/dns) ne touchent pas aux boîtes du domaine principal.
resource "oci_email_email_domain" "alerts" {
  compartment_id = oci_identity_compartment.platform.id
  name           = var.alert_mail.domain
  description    = "Domaine d'envoi des alertes de ${var.project}."
  freeform_tags  = local.freeform_tags
}

# Signature DKIM des messages : Oracle garde la clé privée, et la zone DNS publie l'autre moitié
# par un CNAME vers Oracle.
resource "oci_email_dkim" "alerts" {
  email_domain_id = oci_email_email_domain.alerts.id
  name            = var.alert_mail.dkim_selector
  description     = "Signature des alertes de ${var.project}."
  freeform_tags   = local.freeform_tags
}

# Seule adresse autorisée à émettre.
resource "oci_email_sender" "alerts" {
  compartment_id = oci_identity_compartment.platform.id
  email_address  = "${var.alert_mail.sender}@${oci_email_email_domain.alerts.name}"
  freeform_tags  = local.freeform_tags
}

# Oracle refuse un identifiant SMTP à un utilisateur de service : celui-ci est donc un
# utilisateur ordinaire, à qui toutes les autres capacités sont retirées. Il n'a ni mot de passe
# ni accès à la console, et son adresse, sans boîte, ne reçoit rien.
resource "oci_identity_domains_user" "alerts" {
  idcs_endpoint = local.identity_domain_url
  user_name     = "${var.project}-alerts"
  description   = "Envoi du courrier des alertes par Alertmanager."
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:capabilities:User",
  ]

  name {
    family_name = "${var.project}-alerts"
  }

  emails {
    type    = "work"
    value   = oci_email_sender.alerts.email_address
    primary = true
  }

  urnietfparamsscimschemasoracleidcsextensionuser_user {
    # Aucun message de bienvenue : personne ne le lirait.
    bypass_notification = true
  }

  urnietfparamsscimschemasoracleidcsextensioncapabilities_user {
    can_use_smtp_credentials         = true
    can_use_api_keys                 = false
    can_use_auth_tokens              = false
    can_use_console_password         = false
    can_use_customer_secret_keys     = false
    can_use_db_credentials           = false
    can_use_oauth2client_credentials = false
  }

  lifecycle {
    # Oracle ajoute à « schemas » des extensions (OCITags, userState…) selon les attributs
    # renvoyés, double l'adresse d'une adresse de récupération, et ne renvoie pas
    # bypass_notification, qui ne sert qu'à la création : y revenir à chaque plan n'aurait aucun
    # effet.
    ignore_changes = [
      schemas,
      emails,
      urnietfparamsscimschemasoracleidcsextensionuser_user,
    ]
  }
}

resource "oci_identity_domains_group" "alerts" {
  idcs_endpoint  = local.identity_domain_url
  display_name   = "${var.project}-alerts"
  attribute_sets = local.identity_read_attribute_sets
  schemas        = ["urn:ietf:params:scim:schemas:core:2.0:Group"]

  members {
    type  = "User"
    value = oci_identity_domains_user.alerts.id
  }

  lifecycle {
    ignore_changes = [schemas]
  }
}

# Le groupe peut émettre depuis les adresses autorisées du compartiment, et rien d'autre.
resource "oci_identity_policy" "alerts" {
  compartment_id = oci_identity_compartment.platform.id
  name           = "${var.project}-alerts"
  description    = "Laisse Alertmanager envoyer le courrier des alertes."
  freeform_tags  = local.freeform_tags

  statements = [
    join(" ", [
      "Allow group '${var.identity_domain_name}'/'${oci_identity_domains_group.alerts.display_name}'",
      "to use approved-senders in compartment ${oci_identity_compartment.platform.name}",
    ]),
  ]
}

# Identifiant et mot de passe SMTP. Le mot de passe n'est lisible qu'à la création : il reste
# dans le state, chiffré dans le bucket, d'où scripts/alertmanager-email.sh le porte au cluster.
resource "oci_identity_domains_smtp_credential" "alerts" {
  idcs_endpoint = local.identity_domain_url
  description   = "Courrier des alertes, utilisé par Alertmanager."
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:smtpCredential"]

  user {
    value = oci_identity_domains_user.alerts.id
  }
}
