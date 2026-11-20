# Le socle (compartiment, tags) est géré par terraform/bootstrap : la prod le lit dans son state
# au lieu de recopier ses identifiants.
data "terraform_remote_state" "bootstrap" {
  backend = "oci"

  config = {
    bucket              = var.state_bucket
    namespace           = var.objectstorage_namespace
    key                 = var.bootstrap_state_key
    region              = var.region
    auth                = var.oci_auth
    config_file_profile = var.oci_profile
  }
}

locals {
  compartment_id = data.terraform_remote_state.bootstrap.outputs.compartment_id
  tag_namespace  = data.terraform_remote_state.bootstrap.outputs.tag_namespace

  freeform_tags = {
    managed-by = "terraform"
    stack      = "envs/prod"
  }
}

module "network" {
  source = "../../modules/network"

  compartment_id       = local.compartment_id
  name                 = var.name
  freeform_tags        = local.freeform_tags
  vcn_cidr             = var.vcn_cidr
  vcn_dns_label        = var.vcn_dns_label
  subnet_newbits       = var.subnet_newbits
  subnet_netnums       = var.subnet_netnums
  public_ingress_cidrs = var.public_ingress_cidrs
}
