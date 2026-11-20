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

variable "compartment_description" {
  description = "Description affichée dans la console pour le compartiment de la plateforme."
  type        = string
}
