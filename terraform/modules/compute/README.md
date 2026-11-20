# Module `compute`

Nœuds du cluster : des instances flexibles, une par entrée de `nodes`, rattachées au sous-réseau et aux groupes de sécurité réseau des nœuds.

## Choix notables

- **Garde-fous de l'offre gratuite** : la somme des OCPU, de la mémoire et des volumes de démarrage est validée contre `free_tier_limits` avant tout appel à Oracle.
- **Image choisie par filtre** : la plus récente pour le système et la version exacte demandés. Les variantes Minimal ont une version différente (`24.04 Minimal aarch64`) et sont donc exclues.
- **Image figée après la création** : `source_id` est ignoré. Une nouvelle image ne recrée pas les nœuds ; un nœud la prend quand il est remplacé volontairement avec `terraform apply -replace`.
- **Domaines de panne** : les nœuds sont répartis entre les domaines de panne du domaine de disponibilité, dans l'ordre alphabétique de leurs noms.
- **Adresse publique éphémère** : imposée par l'absence de NAT ([ADR 0006](../../../docs/adr/0006-sortir-par-la-passerelle-internet-sans-nat.md)). Le filtrage repose sur les NSG passés en entrée.

## Exemple

```hcl
module "compute" {
  source = "../../modules/compute"

  compartment_id                 = local.compartment_id
  name                           = "rtgre-platform-prod"
  shape                          = "VM.Standard.A1.Flex"
  image_operating_system         = "Canonical Ubuntu"
  image_operating_system_version = "24.04"
  subnet_id                      = module.network.subnet_ids["nodes"]
  nsg_ids                        = [module.network.nsg_ids["nodes"]]
  ssh_authorized_keys            = ["ssh-ed25519 AAAA… rtgre-platform"]
  free_tier_limits               = { ocpus = 2, memory_in_gbs = 12, block_volume_in_gbs = 200 }

  nodes = {
    cp-1 = { role = "control-plane", ocpus = 1, memory_in_gbs = 6, boot_volume_size_in_gbs = 50 }
    wk-1 = { role = "worker", ocpus = 1, memory_in_gbs = 6, boot_volume_size_in_gbs = 50 }
  }
}
```

## Sorties

| Sortie | Contenu |
| --- | --- |
| `nodes` | Par nom d'hôte : OCID, rôle, domaine de panne, adresses privée et publique |
| `image` | Image la plus récente correspondant aux filtres |

## Manque de capacité

Les instances A1 gratuites échouent parfois avec `Out of host capacity`. Voir le runbook [Créer des nœuds A1 sans capacité disponible](../../../docs/runbooks/creer-des-noeuds-sans-capacite-a1.md).
