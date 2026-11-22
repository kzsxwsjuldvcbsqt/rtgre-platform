# Courrier des alertes (ADR 0021). Ce fichier ne contient aucun secret et il est suivi par Git.
alert_mail = {
  # Sous-domaine réservé à l'envoi : terraform/dns y publie le SPF et la clé DKIM.
  domain = "alertes.rtgre.fr"
  # Partie locale de l'adresse d'expédition.
  sender = "cluster"
  # Sélecteur DKIM : en changer permet de renouveler la clé sans coupure.
  dkim_selector = "rtgre-platform-202611"
  # Serveurs d'envoi d'Oracle pour l'Europe, à autoriser dans le SPF du sous-domaine.
  spf_include = "eu.rp.oracleemaildelivery.com"
  smtp_port   = 587
}
