# Identité de la CI : GitHub Actions échange son jeton OIDC contre un jeton Oracle de courte
# durée (UPST), émis au nom d'un utilisateur de service sans mot de passe ni clé API.
# Voir docs/adr/0005-authentifier-la-ci-par-federation-d-identite.md.

data "oci_identity_domains" "this" {
  compartment_id = var.tenancy_ocid
  display_name   = var.identity_domain_name
}

locals {
  identity_domain_url = one(data.oci_identity_domains.this.domains).url

  # Sans « all », l'API ne renvoie ni les membres d'un groupe ni les règles d'emprunt d'une confiance.
  identity_read_attribute_sets = ["all"]

  # Une identité par usage. Le claim « sub » du jeton GitHub dépend de l'événement qui a lancé le
  # workflow ; avec le sujet immuable de GitHub, le préfixe contient aussi les identifiants
  # numériques du propriétaire et du dépôt.
  ci_identities = {
    plan = {
      description = "Plans Terraform lancés par la CI : lecture seule sur le compartiment."
      subjects = [
        "${var.github_oidc_subject_prefix}:pull_request",
        "${var.github_oidc_subject_prefix}:ref:refs/heads/main",
      ]
      grants = [
        { permission = "read all-resources", condition = "" },
      ]
    }

    apply = {
      description = "Applies Terraform lancés depuis l'environnement GitHub ${var.github_apply_environment}."
      subjects = [
        "${var.github_oidc_subject_prefix}:environment:${var.github_apply_environment}",
      ]
      grants = [
        { permission = "read all-resources", condition = "" },
        { permission = "manage virtual-network-family", condition = "" },
        { permission = "manage instance-family", condition = "" },
        { permission = "manage volume-family", condition = "" },
        { permission = "manage bastion-family", condition = "" },
        { permission = "manage network-load-balancers", condition = "" },
        # Alarmes de la plateforme, qui publient dans le sujet des pannes sans pouvoir le modifier.
        { permission = "manage alarms", condition = "" },
        { permission = "use ons-topics", condition = "" },
        { permission = "manage objects", condition = "target.bucket.name = '${oci_objectstorage_bucket.terraform_state.name}'" },
      ]
    }
  }

  ci_impersonation_rules = flatten([
    for key, identity in local.ci_identities : [
      for subject in identity.subjects : { identity = key, subject = subject }
    ]
  ])
}

moved {
  from = oci_identity_domains_user.ci_plan
  to   = oci_identity_domains_user.ci["plan"]
}

moved {
  from = oci_identity_domains_group.ci_plan
  to   = oci_identity_domains_group.ci["plan"]
}

moved {
  from = oci_identity_policy.ci_plan
  to   = oci_identity_policy.ci["plan"]
}

resource "oci_identity_domains_user" "ci" {
  for_each = local.ci_identities

  idcs_endpoint = local.identity_domain_url
  user_name     = "${var.project}-ci-${each.key}"
  description   = each.value.description
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User",
  ]

  name {
    family_name = "${var.project}-ci-${each.key}"
  }

  urnietfparamsscimschemasoracleidcsextensionuser_user {
    service_user = true
  }

  lifecycle {
    # Oracle ajoute à « schemas » des extensions (OCITags, userState, capabilities…) selon les
    # attributs renvoyés : les retirer à chaque plan n'aurait aucun effet.
    ignore_changes = [schemas]
  }
}

resource "oci_identity_domains_group" "ci" {
  for_each = local.ci_identities

  idcs_endpoint  = local.identity_domain_url
  display_name   = "${var.project}-ci-${each.key}"
  attribute_sets = local.identity_read_attribute_sets
  schemas        = ["urn:ietf:params:scim:schemas:core:2.0:Group"]

  members {
    type  = "User"
    value = oci_identity_domains_user.ci[each.key].id
  }

  lifecycle {
    # Oracle ajoute à « schemas » des extensions (OCITags, userState, capabilities…) selon les
    # attributs renvoyés : les retirer à chaque plan n'aurait aucun effet.
    ignore_changes = [schemas]
  }
}

resource "oci_identity_policy" "ci" {
  for_each = local.ci_identities

  compartment_id = oci_identity_compartment.platform.id
  name           = "${var.project}-ci-${each.key}"
  description    = each.value.description
  freeform_tags  = local.freeform_tags

  statements = [
    for grant in each.value.grants : trimspace(join(" ", [
      "Allow group '${var.identity_domain_name}'/'${oci_identity_domains_group.ci[each.key].display_name}'",
      "to ${grant.permission} in compartment ${oci_identity_compartment.platform.name}",
      grant.condition == "" ? "" : "where ${grant.condition}",
    ]))
  ]
}

# Application OAuth dont les identifiants authentifient l'appel d'échange de jeton.
# Ils ne donnent accès à aucune API Oracle sans un jeton GitHub qui respecte la confiance ci-dessous.
resource "oci_identity_domains_app" "ci_token_exchange" {
  idcs_endpoint   = local.identity_domain_url
  display_name    = "${var.project}-ci-token-exchange"
  description     = "Authentifie l'échange du jeton OIDC de GitHub Actions."
  schemas         = ["urn:ietf:params:scim:schemas:oracle:idcs:App"]
  active          = true
  is_oauth_client = true
  client_type     = "confidential"
  allowed_grants  = ["client_credentials"]

  based_on_template {
    value = "CustomWebAppTemplateId"
  }

  lifecycle {
    # Oracle ajoute à « schemas » des extensions (OCITags, userState, capabilities…) selon les
    # attributs renvoyés : les retirer à chaque plan n'aurait aucun effet.
    ignore_changes = [schemas]
  }
}

resource "oci_identity_domains_identity_propagation_trust" "github_actions" {
  idcs_endpoint             = local.identity_domain_url
  name                      = "${var.project}-github-actions"
  description               = "Accepte les jetons OIDC de GitHub Actions pour ${var.github_oidc_subject_prefix}."
  attribute_sets            = local.identity_read_attribute_sets
  schemas                   = ["urn:ietf:params:scim:schemas:oracle:idcs:IdentityPropagationTrust"]
  type                      = "JWT"
  active                    = true
  issuer                    = var.github_oidc_issuer
  public_key_endpoint       = "${var.github_oidc_issuer}/.well-known/jwks"
  oauth_clients             = [oci_identity_domains_app.ci_token_exchange.name]
  subject_type              = "User"
  subject_claim_name        = "sub"
  subject_mapping_attribute = "userName"
  allow_impersonation       = true

  dynamic "impersonation_service_users" {
    for_each = local.ci_impersonation_rules

    content {
      # Sans apostrophes : avec « sub eq '<valeur>' », comme dans les exemples d'Oracle, aucune règle ne correspond.
      rule = "sub eq ${impersonation_service_users.value.subject}"
      # L'API attend l'identifiant SCIM de l'utilisateur (40 caractères au plus), pas son OCID.
      value = oci_identity_domains_user.ci[impersonation_service_users.value.identity].id
      ocid  = oci_identity_domains_user.ci[impersonation_service_users.value.identity].ocid
    }
  }
}
