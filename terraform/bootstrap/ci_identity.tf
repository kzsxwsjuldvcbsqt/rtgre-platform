# Identité de la CI : GitHub Actions échange son jeton OIDC contre un jeton Oracle de courte
# durée (UPST), émis au nom d'un utilisateur de service sans mot de passe ni clé API.
# Voir docs/adr/0005-authentifier-la-ci-par-federation-d-identite.md.

data "oci_identity_domains" "this" {
  compartment_id = var.tenancy_ocid
  display_name   = var.identity_domain_name
}

locals {
  identity_domain_url = one(data.oci_identity_domains.this.domains).url
  ci_plan_name        = "${var.project}-ci-plan"

  # Le claim « sub » du jeton GitHub dépend de l'événement qui a lancé le workflow.
  ci_plan_subjects = [
    "repo:${var.github_repository}:pull_request",
    "repo:${var.github_repository}:ref:refs/heads/main",
  ]
}

resource "oci_identity_domains_user" "ci_plan" {
  idcs_endpoint = local.identity_domain_url
  user_name     = local.ci_plan_name
  description   = "Identité de la CI pour les plans Terraform : lecture seule sur le compartiment."
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User",
  ]

  name {
    family_name = local.ci_plan_name
  }

  urnietfparamsscimschemasoracleidcsextensionuser_user {
    service_user = true
  }
}

resource "oci_identity_domains_group" "ci_plan" {
  idcs_endpoint = local.identity_domain_url
  display_name  = local.ci_plan_name
  schemas       = ["urn:ietf:params:scim:schemas:core:2.0:Group"]

  members {
    type  = "User"
    value = oci_identity_domains_user.ci_plan.id
  }
}

resource "oci_identity_policy" "ci_plan" {
  compartment_id = oci_identity_compartment.platform.id
  name           = local.ci_plan_name
  description    = "Lecture seule pour les plans Terraform lancés par la CI."
  freeform_tags  = local.freeform_tags

  statements = [
    "Allow group '${var.identity_domain_name}'/'${oci_identity_domains_group.ci_plan.display_name}' to read all-resources in compartment ${oci_identity_compartment.platform.name}",
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
}

resource "oci_identity_domains_identity_propagation_trust" "github_actions" {
  idcs_endpoint             = local.identity_domain_url
  name                      = "${var.project}-github-actions"
  description               = "Accepte les jetons OIDC de GitHub Actions pour ${var.github_repository}."
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
    for_each = local.ci_plan_subjects

    content {
      rule = "sub eq '${impersonation_service_users.value}'"
      # L'API attend l'identifiant SCIM de l'utilisateur (40 caractères au plus), pas son OCID.
      value = oci_identity_domains_user.ci_plan.id
      ocid  = oci_identity_domains_user.ci_plan.ocid
    }
  }
}
