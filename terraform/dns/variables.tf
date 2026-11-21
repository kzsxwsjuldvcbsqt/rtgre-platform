variable "ovh_endpoint" {
  description = "Point d'accès de l'API d'OVH, par exemple ovh-eu."
  type        = string
}

variable "region" {
  description = "Région Oracle Cloud du bucket des states, par exemple eu-paris-1."
  type        = string
}

variable "oci_auth" {
  description = "Méthode d'authentification Oracle pour lire le state de la prod."
  type        = string
  default     = "APIKey"
}

variable "oci_profile" {
  description = "Profil du fichier ~/.oci/config utilisé pour lire le state de la prod."
  type        = string
  default     = "DEFAULT"
}

variable "state_bucket" {
  description = "Bucket Object Storage des states Terraform (sortie state_bucket du bootstrap)."
  type        = string
}

variable "objectstorage_namespace" {
  description = "Namespace Object Storage de la tenancy (sortie objectstorage_namespace du bootstrap)."
  type        = string
}

variable "prod_state_key" {
  description = "Clé du state de la prod dans le bucket."
  type        = string
  default     = "envs/prod/terraform.tfstate"
}

variable "zone" {
  description = "Zone DNS gérée, par exemple example.org."
  type        = string
}

variable "mail_records" {
  description = "Enregistrements dont dépend le courrier (MX, SPF). Terraform refuse de les supprimer."
  type = map(object({
    subdomain = string
    fieldtype = string
    ttl       = number
    target    = string
  }))

  validation {
    condition     = alltrue([for record in values(var.mail_records) : contains(["MX", "TXT", "SPF", "DKIM", "DMARC"], record.fieldtype)])
    error_message = "mail_records n'accepte que des enregistrements MX, TXT, SPF, DKIM ou DMARC."
  }

  validation {
    condition     = alltrue([for record in values(var.mail_records) : record.ttl >= 60])
    error_message = "OVH exige une durée de vie d'au moins 60 secondes."
  }
}

variable "records" {
  description = "Autres enregistrements de la zone, écrits tels quels."
  type = map(object({
    subdomain = string
    fieldtype = string
    ttl       = number
    target    = string
  }))

  validation {
    condition     = alltrue([for record in values(var.records) : record.ttl >= 60])
    error_message = "OVH exige une durée de vie d'au moins 60 secondes."
  }
}

variable "cluster_subdomains" {
  description = "Noms qui désignent le load balancer du cluster. Une chaîne vide désigne le sommet de la zone."
  type        = set(string)
}

variable "cluster_ttl" {
  description = "Durée de vie des enregistrements qui désignent le cluster. Courte : l'adresse du load balancer peut changer."
  type        = number

  validation {
    condition     = var.cluster_ttl >= 60
    error_message = "OVH exige une durée de vie d'au moins 60 secondes."
  }
}
