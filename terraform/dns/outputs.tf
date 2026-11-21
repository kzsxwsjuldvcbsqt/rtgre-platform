output "zone" {
  description = "Zone DNS gérée."
  value       = var.zone
}

output "site_served_by" {
  description = "Ce qui sert le site au sommet de la zone : github-pages ou cluster."
  value       = var.site_served_by
}

output "cluster_names" {
  description = "Noms complets qui désignent le load balancer du cluster, et l'adresse qu'ils portent."
  value = {
    for key, record in local.cluster_records :
    trimprefix("${record.subdomain}.${var.zone}", ".") => record.target
  }
}
