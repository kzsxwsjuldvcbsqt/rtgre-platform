variable "compartment_id" {
  description = "OCID du compartiment qui accueille le Bastion."
  type        = string
}

variable "name" {
  description = "Nom du Bastion : lettres et chiffres uniquement."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9]{1,255}$", var.name))
    error_message = "Le nom d'un Bastion ne peut contenir que des lettres et des chiffres."
  }
}

variable "freeform_tags" {
  description = "Tags libres appliqués aux ressources du module."
  type        = map(string)
  default     = {}
}

variable "target_subnet_id" {
  description = "Sous-réseau des nœuds : le Bastion y place son point d'accès privé."
  type        = string
}

variable "target_nsg_id" {
  description = "Groupe de sécurité réseau des nœuds, qui reçoit la règle SSH depuis le Bastion."
  type        = string
}

variable "client_cidr_block_allow_list" {
  description = "Plages autorisées à se connecter au Bastion. La création d'une session exige en plus une authentification Oracle."
  type        = list(string)

  validation {
    condition     = length(var.client_cidr_block_allow_list) > 0 && alltrue([for cidr in var.client_cidr_block_allow_list : can(cidrnetmask(cidr))])
    error_message = "client_cidr_block_allow_list doit contenir au moins une plage IPv4 au format CIDR."
  }
}

variable "max_session_ttl_in_seconds" {
  description = "Durée de vie maximale d'une session, de 30 minutes à 3 heures."
  type        = number

  validation {
    condition     = var.max_session_ttl_in_seconds >= 1800 && var.max_session_ttl_in_seconds <= 10800
    error_message = "max_session_ttl_in_seconds doit être compris entre 1800 et 10800."
  }
}

variable "ssh_port" {
  description = "Port SSH des nœuds."
  type        = number
  default     = 22
}
