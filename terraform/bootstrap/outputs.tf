output "compartment_id" {
  description = "OCID du compartiment qui accueille toutes les ressources de la plateforme."
  value       = oci_identity_compartment.platform.id
}

output "compartment_name" {
  description = "Nom du compartiment de la plateforme."
  value       = oci_identity_compartment.platform.name
}

output "budget_id" {
  description = "OCID du budget mensuel de la tenancy."
  value       = oci_budget_budget.tenancy.id
}

output "state_bucket" {
  description = "Bucket Object Storage qui conserve les states Terraform."
  value       = oci_objectstorage_bucket.terraform_state.name
}

output "objectstorage_namespace" {
  description = "Namespace Object Storage de la tenancy, à reporter dans les fichiers backend.hcl."
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "backup_bucket" {
  description = "Bucket Object Storage qui reçoit les sauvegardes de la plateforme."
  value       = oci_objectstorage_bucket.backups.name
}

output "tag_namespace" {
  description = "Espace de noms des tags définis de la plateforme."
  value       = oci_identity_tag_namespace.platform.name
}

output "identity_domain_url" {
  description = "URL du domaine d'identité, point d'entrée de l'échange de jeton."
  value       = local.identity_domain_url
}

output "ci_token_exchange_client_id" {
  description = "Identifiant de l'application OAuth qui authentifie l'échange de jeton de la CI."
  value       = oci_identity_domains_app.ci_token_exchange.name
}

output "ci_token_exchange_client_secret" {
  description = "Secret de l'application OAuth de la CI, à déposer dans les secrets GitHub."
  value       = oci_identity_domains_app.ci_token_exchange.client_secret
  sensitive   = true
}

output "alert_mail" {
  description = "Envoi du courrier des alertes : serveur SMTP, expéditeur, et enregistrements DNS à publier pour le domaine d'envoi."
  value = {
    smtp_host   = "smtp.email.${var.region}.oci.oraclecloud.com"
    smtp_port   = var.alert_mail.smtp_port
    sender      = oci_email_sender.alerts.email_address
    domain      = oci_email_email_domain.alerts.name
    spf         = "v=spf1 include:${var.alert_mail.spf_include} -all"
    dkim_name   = oci_email_dkim.alerts.dns_subdomain_name
    dkim_target = oci_email_dkim.alerts.cname_record_value
  }
}

output "alert_smtp_username" {
  description = "Identifiant SMTP d'Alertmanager."
  value       = oci_identity_domains_smtp_credential.alerts.user_name
}

output "alert_smtp_password" {
  description = "Mot de passe SMTP d'Alertmanager."
  value       = oci_identity_domains_smtp_credential.alerts.password
  sensitive   = true
}

output "outage_topic_id" {
  description = "Sujet de notification des pannes vues depuis Oracle : destination des alarmes de la plateforme."
  value       = oci_ons_notification_topic.outages.id
}
