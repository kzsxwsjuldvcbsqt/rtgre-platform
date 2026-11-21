# Network Load Balancer d'Oracle : il transmet des connexions TCP sans les déchiffrer. Un par
# tenancy est gratuit (ADR 0012). Le TLS est terminé dans le cluster.
resource "oci_network_load_balancer_network_load_balancer" "this" {
  compartment_id             = var.compartment_id
  display_name               = var.name
  subnet_id                  = var.subnet_id
  network_security_group_ids = var.nsg_ids
  is_private                 = false
  freeform_tags              = var.freeform_tags

  # Le load balancer se présente aux instances avec sa propre adresse : leurs groupes de sécurité
  # n'ont alors à l'accepter que lui, pas Internet. L'adresse du client passe par le PROXY protocol.
  is_preserve_source_destination = false
}

locals {
  backends = {
    for pair in setproduct(keys(var.listeners), keys(var.backends)) :
    "${pair[0]}:${pair[1]}" => { listener = pair[0], backend = pair[1] }
  }
}

resource "oci_network_load_balancer_backend_set" "this" {
  for_each = var.listeners

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id
  name                     = each.key
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = false

  # Une instance dont le port ne répond plus ne reçoit plus de trafic.
  health_checker {
    protocol           = "TCP"
    port               = each.value.backend_port
    interval_in_millis = var.health_check.interval_in_millis
    timeout_in_millis  = var.health_check.timeout_in_millis
    retries            = var.health_check.retries
  }
}

resource "oci_network_load_balancer_backend" "this" {
  for_each = local.backends

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id
  backend_set_name         = oci_network_load_balancer_backend_set.this[each.value.listener].name
  name                     = each.value.backend
  target_id                = var.backends[each.value.backend]
  port                     = var.listeners[each.value.listener].backend_port
}

resource "oci_network_load_balancer_listener" "this" {
  for_each = var.listeners

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.this.id
  name                     = each.key
  protocol                 = "TCP"
  port                     = each.value.port
  default_backend_set_name = oci_network_load_balancer_backend_set.this[each.key].name
  is_ppv2enabled           = var.proxy_protocol_enabled
}
