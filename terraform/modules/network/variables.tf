variable "compartment_id" {
  description = "OCID du compartiment qui accueille le réseau."
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

variable "vcn_cidr" {
  description = "Plage d'adresses IPv4 du réseau virtuel, par exemple 10.0.0.0/16."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vcn_cidr))
    error_message = "vcn_cidr doit être une plage IPv4 au format CIDR."
  }
}

variable "vcn_dns_label" {
  description = "Label DNS du réseau virtuel : une lettre puis au plus 14 lettres ou chiffres."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,14}$", var.vcn_dns_label))
    error_message = "vcn_dns_label doit commencer par une lettre et ne contenir que 15 lettres minuscules ou chiffres au plus."
  }
}

variable "subnet_newbits" {
  description = "Bits ajoutés au masque du réseau virtuel pour obtenir celui de chaque sous-réseau (8 sur un /16 donne des /24)."
  type        = number

  validation {
    condition     = var.subnet_newbits >= 1 && var.subnet_newbits <= 16
    error_message = "subnet_newbits doit être compris entre 1 et 16."
  }
}

variable "subnet_netnums" {
  description = "Numéro de chaque sous-réseau dans le réseau virtuel. Les plages sont calculées avec cidrsubnet : des numéros distincts garantissent l'absence de chevauchement."
  type = object({
    load_balancer = number
    nodes         = number
  })

  validation {
    condition     = length(distinct(values(var.subnet_netnums))) == length(values(var.subnet_netnums))
    error_message = "Chaque sous-réseau doit avoir un numéro distinct, sinon leurs plages se chevauchent."
  }

  validation {
    condition     = alltrue([for netnum in values(var.subnet_netnums) : netnum >= 0 && netnum < pow(2, var.subnet_newbits)])
    error_message = "Chaque numéro de sous-réseau doit être compris entre 0 et 2^subnet_newbits - 1."
  }
}

variable "public_ingress_cidrs" {
  description = "Plages autorisées à joindre le load balancer depuis Internet."
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.public_ingress_cidrs : can(cidrnetmask(cidr))])
    error_message = "public_ingress_cidrs ne doit contenir que des plages IPv4 au format CIDR."
  }
}

variable "public_ingress_ports" {
  description = "Ports TCP ouverts sur le load balancer."
  type        = list(number)
  default     = [80, 443]
}

variable "nodes_subnet_ssh_egress_port" {
  description = "Port SSH que la liste de sécurité par défaut autorise en sortie vers le sous-réseau des nœuds, pour le point d'accès du Bastion. null : aucune sortie."
  type        = number
  default     = null
}
