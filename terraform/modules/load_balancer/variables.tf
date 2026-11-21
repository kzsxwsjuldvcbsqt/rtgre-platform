variable "compartment_id" {
  description = "OCID du compartiment qui accueille le load balancer."
  type        = string
}

variable "name" {
  description = "Nom du load balancer."
  type        = string
}

variable "freeform_tags" {
  description = "Tags libres appliqués aux ressources du module."
  type        = map(string)
  default     = {}
}

variable "subnet_id" {
  description = "Sous-réseau public qui porte l'adresse du load balancer."
  type        = string
}

variable "nsg_ids" {
  description = "Groupes de sécurité réseau du load balancer."
  type        = list(string)
}

variable "backends" {
  description = "Instances qui reçoivent le trafic, par nom : leur OCID."
  type        = map(string)

  validation {
    condition     = length(var.backends) > 0
    error_message = "Le load balancer a besoin d'au moins une instance."
  }
}

variable "listeners" {
  description = "Ports TCP écoutés, par nom : le port public et le port des instances qui le reçoit."
  type = map(object({
    port         = number
    backend_port = number
  }))

  validation {
    condition = alltrue([
      for listener in values(var.listeners) :
      listener.port >= 1 && listener.port <= 65535 && listener.backend_port >= 1 && listener.backend_port <= 65535
    ])
    error_message = "Chaque port doit être compris entre 1 et 65535."
  }

  validation {
    condition     = length(distinct([for listener in values(var.listeners) : listener.port])) == length(var.listeners)
    error_message = "Deux écoutes ne peuvent pas partager le même port public."
  }
}

variable "proxy_protocol_enabled" {
  description = "Transmet l'adresse du client aux instances par le PROXY protocol v2. Ce qui écoute sur les instances doit alors l'attendre."
  type        = bool
}

variable "health_check" {
  description = "Sonde TCP des instances : intervalle et délai en millisecondes, nombre d'échecs avant de retirer une instance."
  type = object({
    interval_in_millis = number
    timeout_in_millis  = number
    retries            = number
  })
  default = {
    interval_in_millis = 10000
    timeout_in_millis  = 3000
    retries            = 3
  }
}
