# Le budget couvre toute la tenancy, pour repérer aussi une ressource créée hors du compartiment.
# Il mesure le coût d'usage avant crédits : une ressource hors de l'offre gratuite le fait monter
# même pendant la période d'essai.
resource "oci_budget_budget" "tenancy" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.project}-monthly"
  # Sans accent : l'API des budgets renvoie « é » sous la forme « &eacute; », ce qui crée un écart à chaque plan.
  description   = "Suivi mensuel de la tenancy ; la plateforme doit rester dans l'offre Always Free."
  amount        = var.monthly_budget_amount
  reset_period  = "MONTHLY"
  target_type   = "COMPARTMENT"
  targets       = [var.tenancy_ocid]
  freeform_tags = local.freeform_tags
}

resource "oci_budget_alert_rule" "first_spend" {
  budget_id      = oci_budget_budget.tenancy.id
  display_name   = "first-spend"
  description    = "Prévient dès qu'une dépense réelle apparaît."
  type           = "ACTUAL"
  threshold_type = "ABSOLUTE"
  threshold      = var.first_spend_threshold
  recipients     = join(",", var.budget_alert_recipients)
  message        = "Une dépense est apparue sur la tenancy de ${var.project} : une ressource est sortie de l'offre Always Free."
  freeform_tags  = local.freeform_tags
}

resource "oci_budget_alert_rule" "forecast_overrun" {
  budget_id      = oci_budget_budget.tenancy.id
  display_name   = "forecast-overrun"
  description    = "Prévient quand la prévision du mois dépasse le budget."
  type           = "FORECAST"
  threshold_type = "PERCENTAGE"
  threshold      = 100
  recipients     = join(",", var.budget_alert_recipients)
  message        = "La prévision de dépenses de ${var.project} dépasse le budget mensuel."
  freeform_tags  = local.freeform_tags
}
