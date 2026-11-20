variable "compartment_id" {
  description = "OCID du compartiment qui accueille les nœuds."
  type        = string
}

variable "name" {
  description = "Préfixe des noms affichés des ressources, par exemple rtgre-platform-prod."
  type        = string
}

variable "freeform_tags" {
  description = "Tags libres appliqués à toutes les ressources du module."
  type        = map(string)
  default     = {}
}

variable "shape" {
  description = "Forme flexible des instances, par exemple VM.Standard.A1.Flex."
  type        = string
}

variable "image_operating_system" {
  description = "Système d'exploitation de l'image, tel que le nomme Oracle (par exemple Canonical Ubuntu)."
  type        = string
}

variable "image_operating_system_version" {
  description = "Version exacte du système, par exemple 24.04. Les variantes Minimal ont une autre version et sont donc exclues."
  type        = string
}

variable "subnet_id" {
  description = "OCID du sous-réseau des nœuds."
  type        = string
}

variable "nsg_ids" {
  description = "Groupes de sécurité réseau rattachés à la carte réseau de chaque nœud."
  type        = list(string)
}

variable "ssh_authorized_keys" {
  description = "Clés SSH publiques autorisées pour l'utilisateur par défaut de l'image."
  type        = list(string)

  validation {
    condition     = length(var.ssh_authorized_keys) > 0 && alltrue([for key in var.ssh_authorized_keys : can(regex("^ssh-(ed25519|rsa) ", key))])
    error_message = "ssh_authorized_keys doit contenir au moins une clé publique ssh-ed25519 ou ssh-rsa."
  }
}

variable "nodes" {
  description = "Nœuds à créer, par nom d'hôte : rôle Kubernetes, OCPU, mémoire et taille du volume de démarrage."
  type = map(object({
    role                    = string
    ocpus                   = number
    memory_in_gbs           = number
    boot_volume_size_in_gbs = number
  }))

  validation {
    condition     = alltrue([for node in values(var.nodes) : contains(["control-plane", "worker"], node.role)])
    error_message = "Le rôle d'un nœud doit valoir control-plane ou worker."
  }

  validation {
    condition     = alltrue([for hostname in keys(var.nodes) : can(regex("^[a-z][a-z0-9-]{0,14}$", hostname))])
    error_message = "Chaque nom de nœud doit commencer par une lettre et ne contenir que 15 minuscules, chiffres ou tirets au plus."
  }

  validation {
    condition     = sum([for node in values(var.nodes) : node.ocpus]) <= var.free_tier_limits.ocpus
    error_message = "Le total des OCPU dépasse la limite de l'offre gratuite (free_tier_limits.ocpus)."
  }

  validation {
    condition     = sum([for node in values(var.nodes) : node.memory_in_gbs]) <= var.free_tier_limits.memory_in_gbs
    error_message = "Le total de la mémoire dépasse la limite de l'offre gratuite (free_tier_limits.memory_in_gbs)."
  }

  validation {
    condition     = sum([for node in values(var.nodes) : node.boot_volume_size_in_gbs]) <= var.free_tier_limits.block_volume_in_gbs
    error_message = "Le total des volumes de démarrage dépasse le stockage bloc de l'offre gratuite (free_tier_limits.block_volume_in_gbs)."
  }
}

variable "free_tier_limits" {
  description = "Limites de l'offre Always Free que les nœuds ne doivent pas dépasser."
  type = object({
    ocpus               = number
    memory_in_gbs       = number
    block_volume_in_gbs = number
  })
}
