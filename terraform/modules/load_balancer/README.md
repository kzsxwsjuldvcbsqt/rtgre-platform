# Module `load_balancer`

Network Load Balancer public d'Oracle, devant les nœuds du cluster ([ADR 0012](../../../docs/adr/0012-exposer-par-un-network-load-balancer-et-gateway-api.md)).

- Une écoute TCP par entrée de `listeners`, avec son groupe d'instances et sa sonde TCP.
- Les instances de `backends` reçoivent chaque écoute sur son `backend_port`.
- Le TLS n'est pas terminé ici : les connexions sont transmises telles quelles.

## Choix notables

- **Network Load Balancer plutôt que Load Balancer** : il transmet du TCP sans rien déchiffrer, donc les certificats et leurs clés restent dans le cluster. L'offre gratuite en comprend un, sans limite de débit à 10 Mbps.
- **L'adresse source n'est pas préservée** (`is_preserve_source_destination = false`) : les instances voient l'adresse privée du load balancer. Leur groupe de sécurité n'accepte alors que lui. Si l'adresse du client était préservée, il faudrait ouvrir leurs ports à Internet, et les nœuds ont une adresse publique.
- **PROXY protocol v2** (`proxy_protocol_enabled`) : l'adresse du client est transmise en tête de chaque connexion. Ce qui écoute sur les instances doit l'attendre, et ne l'accepter que du load balancer.
- **Sonde TCP** : une sonde HTTP n'enverrait pas l'en-tête du PROXY protocol et serait rejetée.
- **Adresse éphémère** : elle change si le load balancer est recréé. Le DNS la lit dans la sortie `public_ip`.

## Exemple

```hcl
module "load_balancer" {
  source = "../../modules/load_balancer"

  compartment_id = local.compartment_id
  name           = "${var.name}-web"
  freeform_tags  = local.freeform_tags
  subnet_id      = module.network.subnet_ids["load_balancer"]
  nsg_ids        = [module.network.nsg_ids["load_balancer"]]
  backends       = { for hostname, node in module.compute.nodes : hostname => node.id if node.role == "worker" }

  listeners = {
    http  = { port = 80, backend_port = 30080 }
    https = { port = 443, backend_port = 30443 }
  }
  proxy_protocol_enabled = true
}
```
