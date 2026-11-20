# Module `network`

Réseau virtuel de la plateforme : un réseau virtuel, une passerelle Internet, un sous-réseau par rôle et un groupe de sécurité réseau (NSG) par rôle.

## Choix notables

- **Pas de NAT** : les nœuds sortent par la passerelle Internet avec une adresse publique éphémère, faute de passerelle NAT dans l'offre Always Free ([ADR 0006](../../../docs/adr/0006-sortir-par-la-passerelle-internet-sans-nat.md)).
- **Liste de sécurité par défaut vidée** : celle d'Oracle ouvre SSH à tout Internet. Tout le filtrage passe par les NSG.
- **Plages calculées, jamais saisies** : chaque sous-réseau vaut `cidrsubnet(vcn_cidr, subnet_newbits, numéro)`. Les numéros sont validés comme distincts, donc deux sous-réseaux ne peuvent pas se chevaucher.

## Filtrage

| NSG | Entrée | Sortie |
| --- | --- | --- |
| `load_balancer` | TCP `public_ingress_ports` depuis `public_ingress_cidrs` | TCP vers le NSG `nodes` |
| `nodes` | Tout depuis `nodes` ; TCP depuis `load_balancer` ; ICMP 3/4 (MTU) | Tout |

Une ressource n'est protégée que si sa carte réseau est rattachée au NSG de son rôle.

## Exemple

```hcl
module "network" {
  source = "../../modules/network"

  compartment_id       = local.compartment_id
  name                 = "rtgre-platform-prod"
  freeform_tags        = local.freeform_tags
  vcn_cidr             = "10.20.0.0/16"
  vcn_dns_label        = "rtgreprod"
  subnet_newbits       = 8
  subnet_netnums       = { load_balancer = 10, nodes = 20 }
  public_ingress_cidrs = ["0.0.0.0/0"]
}
```

## Sorties

| Sortie | Contenu |
| --- | --- |
| `vcn_id`, `vcn_cidr` | Réseau virtuel |
| `subnet_ids`, `subnet_cidrs` | Sous-réseaux, par rôle |
| `nsg_ids` | Groupes de sécurité réseau, par rôle |
