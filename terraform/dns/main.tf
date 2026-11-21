# L'adresse du load balancer n'est pas recopiée : elle est lue dans le state de la prod. S'il est
# recréé, un apply de cette configuration suffit à faire suivre le DNS.
data "terraform_remote_state" "prod" {
  backend = "oci"

  config = {
    bucket              = var.state_bucket
    namespace           = var.objectstorage_namespace
    key                 = var.prod_state_key
    region              = var.region
    auth                = var.oci_auth
    config_file_profile = var.oci_profile
  }
}

locals {
  cluster_ip = data.terraform_remote_state.prod.outputs.load_balancer.public_ip
  on_cluster = var.site_served_by == "cluster"

  # Le sommet de la zone et www suivent var.site_served_by : changer cette seule valeur bascule
  # le site, dans un sens comme dans l'autre. Le cluster n'a pas d'IPv6.
  site_ttl  = local.on_cluster ? var.cluster_ttl : 0
  site_ipv4 = local.on_cluster ? [local.cluster_ip] : var.github_pages.ipv4
  site_ipv6 = local.on_cluster ? [] : var.github_pages.ipv6

  site_records = merge(
    {
      for index, address in local.site_ipv4 :
      "site:a:${index}" => { subdomain = "", fieldtype = "A", ttl = local.site_ttl, target = address }
    },
    {
      for index, address in local.site_ipv6 :
      "site:aaaa:${index}" => { subdomain = "", fieldtype = "AAAA", ttl = local.site_ttl, target = address }
    },
    {
      # Un CNAME dans les deux cas : la bascule modifie l'enregistrement sans le recréer.
      "site:www" = {
        subdomain = "www"
        fieldtype = "CNAME"
        ttl       = local.site_ttl
        target    = local.on_cluster ? "${var.zone}." : var.github_pages.www_target
      }
    },
  )

  cluster_records = {
    for subdomain in var.cluster_subdomains :
    "cluster:${subdomain == "" ? "@" : subdomain}" => {
      subdomain = subdomain
      fieldtype = "A"
      ttl       = var.cluster_ttl
      target    = local.cluster_ip
    }
  }
}

# Serveurs de noms et courrier : une suppression par erreur couperait le domaine ou ferait perdre
# des messages. Terraform la refuse, il faut d'abord déplacer l'enregistrement dans var.records.
resource "ovh_domain_zone_record" "protected" {
  for_each = var.protected_records

  zone      = var.zone
  subdomain = each.value.subdomain
  fieldtype = each.value.fieldtype
  ttl       = each.value.ttl
  target    = each.value.target

  lifecycle {
    prevent_destroy = true
  }
}

resource "ovh_domain_zone_record" "this" {
  for_each = merge(var.records, local.cluster_records, local.site_records)

  zone      = var.zone
  subdomain = each.value.subdomain
  fieldtype = each.value.fieldtype
  ttl       = each.value.ttl
  target    = each.value.target
}
