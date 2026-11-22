variable "tenancy_ocid" {
  description = "OCID de la tenancy, parent du compartiment et de l'espace de tags."
  type        = string

  validation {
    condition     = startswith(var.tenancy_ocid, "ocid1.tenancy.")
    error_message = "tenancy_ocid doit être l'OCID d'une tenancy (ocid1.tenancy...)."
  }
}

variable "region" {
  description = "Région Oracle Cloud où les ressources sont créées, par exemple eu-paris-1."
  type        = string
}

variable "oci_profile" {
  description = "Profil du fichier ~/.oci/config utilisé pour s'authentifier."
  type        = string
  default     = "DEFAULT"
}

variable "project" {
  description = "Nom court du projet, repris dans les noms et les tags des ressources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project))
    error_message = "project doit commencer par une lettre et ne contenir que des minuscules, des chiffres et des tirets."
  }
}

variable "environment" {
  description = "Environnement porté par le compartiment, par exemple prod."
  type        = string
}

variable "tag_propagation_delay" {
  description = "Attente entre la création des tags et leur première utilisation, le temps qu'Oracle les propage."
  type        = string
  default     = "30s"
}

variable "policy_propagation_delay" {
  description = "Attente entre la création d'une politique IAM et sa première utilisation, le temps qu'Oracle l'applique."
  type        = string
  default     = "60s"
}

variable "state_key_length" {
  description = "Longueur, en octets, de la clé AES qui chiffre le bucket du state."
  type        = number
  default     = 32

  validation {
    condition     = contains([16, 24, 32], var.state_key_length)
    error_message = "Une clé AES fait 16, 24 ou 32 octets."
  }
}

variable "compartment_description" {
  description = "Description affichée dans la console pour le compartiment de la plateforme."
  type        = string
}

variable "monthly_budget_amount" {
  description = "Budget mensuel de la tenancy, dans la devise du compte."
  type        = number

  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "monthly_budget_amount doit être strictement positif."
  }
}

variable "first_spend_threshold" {
  description = "Dépense réelle, dans la devise du compte, à partir de laquelle l'alerte de première dépense part."
  type        = number

  validation {
    condition     = var.first_spend_threshold > 0
    error_message = "first_spend_threshold doit être strictement positif."
  }
}

variable "budget_alert_recipients" {
  description = "Adresses e-mail qui reçoivent les alertes de budget."
  type        = list(string)

  validation {
    condition     = length(var.budget_alert_recipients) > 0 && alltrue([for address in var.budget_alert_recipients : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", address))])
    error_message = "budget_alert_recipients doit contenir au moins une adresse e-mail valide."
  }
}

variable "outage_alert_recipients" {
  description = "Adresses e-mail prévenues des pannes vues depuis Oracle, hors du cluster."
  type        = list(string)

  validation {
    condition     = length(var.outage_alert_recipients) > 0 && alltrue([for address in var.outage_alert_recipients : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", address))])
    error_message = "outage_alert_recipients doit contenir au moins une adresse e-mail valide."
  }
}

variable "identity_domain_name" {
  description = "Nom du domaine d'identité qui porte l'utilisateur de service et la confiance de la CI."
  type        = string
  default     = "Default"
}

variable "github_oidc_subject_prefix" {
  description = "Préfixe du claim sub des jetons OIDC du dépôt autorisé, tel que renvoyé par gh api repos/<propriétaire>/<dépôt>/actions/oidc/customization/sub (champ sub_claim_prefix)."
  type        = string

  validation {
    condition     = can(regex("^repo:[^:]+$", var.github_oidc_subject_prefix))
    error_message = "github_oidc_subject_prefix doit commencer par « repo: » et ne pas contenir le type d'événement."
  }
}

variable "github_oidc_issuer" {
  description = "Émetteur des jetons OIDC de GitHub Actions."
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "github_apply_environment" {
  description = "Environnement GitHub dont les jobs peuvent emprunter l'identité d'apply de la CI."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.github_apply_environment))
    error_message = "github_apply_environment ne doit contenir que des lettres, des chiffres, des points, des tirets ou des tirets bas."
  }
}

variable "alert_mail" {
  description = "Envoi du courrier des alertes : domaine, partie locale de l'expéditeur, sélecteur DKIM, serveurs à autoriser dans le SPF et port SMTP."
  type = object({
    domain        = string
    sender        = string
    dkim_selector = string
    spf_include   = string
    smtp_port     = number
  })
}

variable "free_tier_quotas" {
  description = "Limites de l'offre Always Free appliquées en quotas à toute la tenancy."
  type = object({
    a1_ocpus                = number
    a1_memory_in_gbs        = number
    block_storage_in_gbs    = number
    block_backups           = number
    object_storage_in_bytes = number
    network_load_balancers  = number
    vaults                  = number
    mail_senders            = number
    mails_per_day           = number
    notification_topics     = number
  })

  validation {
    condition     = alltrue([for value in values(var.free_tier_quotas) : value >= 0 && floor(value) == value])
    error_message = "Chaque quota doit être un entier positif ou nul."
  }
}
