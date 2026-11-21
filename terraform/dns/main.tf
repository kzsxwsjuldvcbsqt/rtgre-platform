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
  cluster_records = {
    for subdomain in var.cluster_subdomains :
    "cluster:${subdomain == "" ? "@" : subdomain}" => {
      subdomain = subdomain
      fieldtype = "A"
      ttl       = var.cluster_ttl
      target    = data.terraform_remote_state.prod.outputs.load_balancer.public_ip
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
  for_each = merge(var.records, local.cluster_records)

  zone      = var.zone
  subdomain = each.value.subdomain
  fieldtype = each.value.fieldtype
  ttl       = each.value.ttl
  target    = each.value.target
}
