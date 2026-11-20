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
