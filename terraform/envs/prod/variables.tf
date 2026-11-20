variable "region" {
  description = "Région Oracle Cloud de la plateforme, par exemple eu-paris-1."
  type        = string
}

variable "oci_auth" {
  description = "Méthode d'authentification Oracle : APIKey sur un poste, SecurityToken en CI."
  type        = string
  default     = "APIKey"

  validation {
    condition     = contains(["APIKey", "SecurityToken"], var.oci_auth)
    error_message = "oci_auth doit valoir APIKey ou SecurityToken."
  }
}

variable "oci_profile" {
  description = "Profil du fichier ~/.oci/config utilisé pour s'authentifier."
  type        = string
  default     = "DEFAULT"
}
