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

variable "bootstrap_state_key" {
  description = "Clé du state du bootstrap dans le bucket."
  type        = string
  default     = "bootstrap/terraform.tfstate"
}

variable "zone" {
  description = "Zone DNS gérée, par exemple example.org."
  type        = string
}

variable "protected_records" {
  description = "Enregistrements vitaux : serveurs de noms et courrier. Terraform refuse de les supprimer. Une durée de vie de 0 désigne celle de la zone."
  type = map(object({
    subdomain = string
    fieldtype = string
    ttl       = number
    target    = string
  }))

  validation {
    condition     = alltrue([for record in values(var.protected_records) : contains(["NS", "MX", "TXT", "SPF", "DKIM", "DMARC"], record.fieldtype)])
    error_message = "protected_records n'accepte que des enregistrements NS, MX, TXT, SPF, DKIM ou DMARC."
  }

  validation {
    condition     = alltrue([for record in values(var.protected_records) : record.ttl == 0 || record.ttl >= 60])
    error_message = "Une durée de vie vaut 0, pour celle de la zone, ou au moins 60 secondes."
  }
}

variable "records" {
  description = "Autres enregistrements de la zone, écrits tels quels. Une durée de vie de 0 désigne celle de la zone."
  type = map(object({
    subdomain = string
    fieldtype = string
    ttl       = number
    target    = string
  }))

  validation {
    condition     = alltrue([for record in values(var.records) : record.ttl == 0 || record.ttl >= 60])
    error_message = "Une durée de vie vaut 0, pour celle de la zone, ou au moins 60 secondes."
  }
}

variable "cluster_subdomains" {
  description = "Noms qui désignent le load balancer du cluster. Une chaîne vide désigne le sommet de la zone."
  type        = set(string)
}

variable "cluster_ttl" {
  description = "Durée de vie des enregistrements du site et des noms du cluster. Courte : l'adresse du load balancer peut changer, et une bascule doit se voir vite, dans les deux sens."
  type        = number

  validation {
    condition     = var.cluster_ttl >= 60
    error_message = "OVH exige une durée de vie d'au moins 60 secondes."
  }
}

variable "site_served_by" {
  description = "Ce qui sert le site au sommet de la zone et sous www : github-pages ou cluster."
  type        = string

  validation {
    condition     = contains(["github-pages", "cluster"], var.site_served_by)
    error_message = "site_served_by doit valoir github-pages ou cluster."
  }
}

variable "github_pages" {
  description = "Adresses de GitHub Pages pour un domaine personnalisé, et cible de www."
  type = object({
    ipv4       = list(string)
    ipv6       = list(string)
    www_target = string
  })
}
