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

variable "state_bucket" {
  description = "Bucket Object Storage des states Terraform (sortie state_bucket du bootstrap)."
  type        = string
}

variable "objectstorage_namespace" {
  description = "Namespace Object Storage de la tenancy (sortie objectstorage_namespace du bootstrap)."
  type        = string
}

variable "bootstrap_state_key" {
  description = "Clé du state du bootstrap dans le bucket."
  type        = string
  default     = "bootstrap/terraform.tfstate"
}

variable "name" {
  description = "Préfixe des noms affichés des ressources de cet environnement."
  type        = string
}

variable "vcn_cidr" {
  description = "Plage d'adresses du réseau virtuel."
  type        = string
}

variable "vcn_dns_label" {
  description = "Label DNS du réseau virtuel."
  type        = string
}

variable "subnet_newbits" {
  description = "Bits ajoutés au masque du réseau virtuel pour chaque sous-réseau."
  type        = number
}

variable "subnet_netnums" {
  description = "Numéro de chaque sous-réseau dans le réseau virtuel."
  type = object({
    load_balancer = number
    nodes         = number
  })
}

variable "public_ingress_cidrs" {
  description = "Plages autorisées à joindre le load balancer depuis Internet."
  type        = list(string)
}

variable "node_shape" {
  description = "Forme flexible des nœuds."
  type        = string
}

variable "node_image" {
  description = "Système et version de l'image des nœuds."
  type = object({
    operating_system         = string
    operating_system_version = string
  })
}

variable "ssh_authorized_keys" {
  description = "Clés SSH publiques autorisées sur les nœuds."
  type        = list(string)
}

variable "nodes" {
  description = "Nœuds du cluster, par nom d'hôte."
  type = map(object({
    role                    = string
    ocpus                   = number
    memory_in_gbs           = number
    boot_volume_size_in_gbs = number
  }))
}

variable "free_tier_limits" {
  description = "Limites de l'offre Always Free pour les nœuds."
  type = object({
    ocpus               = number
    memory_in_gbs       = number
    block_volume_in_gbs = number
  })
}

variable "node_agent_plugins" {
  description = "État souhaité des plugins de l'agent Oracle Cloud sur les nœuds."
  type        = map(string)
  default     = {}
}

variable "bastion_client_cidrs" {
  description = "Plages autorisées à se connecter au Bastion."
  type        = list(string)
}

variable "bastion_max_session_ttl_in_seconds" {
  description = "Durée de vie maximale d'une session du Bastion."
  type        = number
}
