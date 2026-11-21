# Paramètres de l'environnement de production. Ils ne contiennent aucun secret et sont suivis par Git ;
# ce qui dépend du poste (authentification, namespace) reste dans terraform.tfvars.
name                 = "rtgre-platform-prod"
vcn_cidr             = "10.20.0.0/16"
vcn_dns_label        = "rtgreprod"
subnet_newbits       = 8
subnet_netnums       = { load_balancer = 10, nodes = 20 }
public_ingress_cidrs = ["0.0.0.0/0"]

# Nœuds : deux instances A1 de 1 OCPU, conformément à l'ADR 0003.
node_shape = "VM.Standard.A1.Flex"
node_image = { operating_system = "Canonical Ubuntu", operating_system_version = "24.04" }

nodes = {
  cp-1 = { role = "control-plane", ocpus = 1, memory_in_gbs = 6, boot_volume_size_in_gbs = 50 }
  wk-1 = { role = "worker", ocpus = 1, memory_in_gbs = 6, boot_volume_size_in_gbs = 50 }
}

# Limites Always Free pour Ampere A1 depuis le 15 juin 2026 (ADR 0002).
free_tier_limits = { ocpus = 2, memory_in_gbs = 12, block_volume_in_gbs = 200 }

ssh_authorized_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICl0AIjV1cKcw7XrTKX9P88cLXexQ047cH4Q0Bqpzhqg rtgre-platform",
]

# Plugins de l'agent Oracle. Le plugin Bastion n'est pas utilisé : les sessions passent par la
# redirection de port, qui n'en dépend pas (#16). Il reste désactivé pour réduire la surface.
node_agent_plugins = {
  Bastion = "DISABLED"
}

# Bastion : l'adresse du poste d'administration change (connexion domestique), donc toutes les
# plages sont admises. Une session exige de toute façon une authentification Oracle et une clé SSH.
bastion_client_cidrs               = ["0.0.0.0/0"]
bastion_max_session_ttl_in_seconds = 10800

# Load balancer : HTTP et HTTPS, vers les ports que la passerelle du cluster ouvre sur les nœuds
# (ports.*.nodePort dans kubernetes/gateway/values.yaml). Elle attend le PROXY protocol.
load_balancer_listeners = {
  http  = { port = 80, backend_port = 30080 }
  https = { port = 443, backend_port = 30443 }
}
load_balancer_proxy_protocol_enabled = true
