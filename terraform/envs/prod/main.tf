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

  # Le Bastion joint les nœuds en SSH depuis le sous-réseau des nœuds.
  nodes_subnet_ssh_egress_port = 22
}

module "compute" {
  source = "../../modules/compute"

  compartment_id                 = local.compartment_id
  name                           = var.name
  freeform_tags                  = local.freeform_tags
  shape                          = var.node_shape
  image_operating_system         = var.node_image.operating_system
  image_operating_system_version = var.node_image.operating_system_version
  subnet_id                      = module.network.subnet_ids["nodes"]
  nsg_ids                        = [module.network.nsg_ids["nodes"]]
  ssh_authorized_keys            = var.ssh_authorized_keys
  nodes                          = var.nodes
  free_tier_limits               = var.free_tier_limits
  agent_plugins                  = var.node_agent_plugins
}

module "bastion" {
  source = "../../modules/bastion"

  compartment_id               = local.compartment_id
  name                         = replace(var.name, "-", "")
  freeform_tags                = local.freeform_tags
  target_subnet_id             = module.network.subnet_ids["nodes"]
  target_nsg_id                = module.network.nsg_ids["nodes"]
  client_cidr_block_allow_list = var.bastion_client_cidrs
  max_session_ttl_in_seconds   = var.bastion_max_session_ttl_in_seconds
}

# Le trafic web entre par le load balancer, vers les nœuds de travail seulement : c'est là que
# tourne la passerelle du cluster.
module "load_balancer" {
  source = "../../modules/load_balancer"

  compartment_id = local.compartment_id
  name           = "${var.name}-web"
  freeform_tags  = local.freeform_tags
  subnet_id      = module.network.subnet_ids["load_balancer"]
  nsg_ids        = [module.network.nsg_ids["load_balancer"]]
  backends       = { for hostname, node in module.compute.nodes : hostname => node.id if node.role == "worker" }

  listeners              = var.load_balancer_listeners
  proxy_protocol_enabled = var.load_balancer_proxy_protocol_enabled

  # Le sujet des pannes et ses abonnés sont créés par le bootstrap.
  alarm = merge(var.load_balancer_alarm, {
    destinations = [data.terraform_remote_state.bootstrap.outputs.outage_topic_id]
  })
}
