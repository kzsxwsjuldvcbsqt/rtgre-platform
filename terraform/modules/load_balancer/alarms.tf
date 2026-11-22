# Alarmes d'Oracle sur la sonde du load balancer : elles voient le cluster du dehors, et partent
# même s'il est tombé en entier, alertes comprises (ADR 0024).

locals {
  healthy_backends = "HealthyBackends[1m]{resourceId = \"${oci_network_load_balancer_network_load_balancer.this.id}\"}"

  alarms = var.alarm == null ? {} : {
    no-healthy-backend = {
      summary = "Aucun nœud ne répond derrière le load balancer : le site est injoignable."
      query   = "${local.healthy_backends}.grouping().min() < 1"
    }
    # Sans instance derrière lui, le load balancer ne publie plus cette métrique du tout.
    no-backend = {
      summary = "Le load balancer n'a plus aucun nœud derrière lui : le site est injoignable."
      query   = "${local.healthy_backends}.grouping().absent()"
    }
  }
}

resource "oci_monitoring_alarm" "this" {
  for_each = local.alarms

  compartment_id        = var.compartment_id
  metric_compartment_id = var.compartment_id
  display_name          = "${var.name}-${each.key}"
  namespace             = "oci_nlb"
  query                 = each.value.query
  severity              = "CRITICAL"
  is_enabled            = true
  freeform_tags         = var.freeform_tags

  # Un nœud qui redémarre manque quelques minutes : l'alarme attend plus longtemps que cela.
  pending_duration             = var.alarm.pending_duration
  repeat_notification_duration = var.alarm.repeat_duration
  destinations                 = var.alarm.destinations
  message_format               = "ONS_OPTIMIZED"
  body                         = "${each.value.summary} Que faire : ${var.alarm.runbook_url}"
}
