# Sauvegardes hors du cluster (ADR 0026). Ce fichier ne contient aucun secret et il est suivi par Git.
backups = {
  # Une sauvegarde par jour : un mois d'historique, quelques dizaines de mégaoctets au plus.
  retention_days = 30
  # Délai après lequel un dépôt resté inachevé est abandonné.
  unfinished_upload_days = 1
}
