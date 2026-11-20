# 0006. Sortir par la passerelle Internet, sans NAT

- Statut : accepté
- Date : 2026-11-20

## Contexte

Les nœuds du cluster ont besoin d'un accès sortant à Internet : paquets du système, images de conteneurs, dépôts de charts. La disposition classique place les nœuds dans un sous-réseau privé, sans adresse publique, et les fait sortir par une passerelle NAT.

Pendant l'essai, la tenancy autorise une passerelle NAT (`nat-gateway-count` = 1). D'après les [retours de la communauté Oracle](https://community.oracle.com/customerconnect/discussion/606991/service-gataway-and-nat-gataway-in-always-free), les tenancies Always Free n'ont droit ni à la passerelle NAT ni à la passerelle de service une fois l'essai terminé. Ce n'est confirmé nulle part dans la documentation officielle. La plateforme doit fonctionner dans l'offre Always Free ([ADR 0002](0002-heberger-sur-oracle-cloud-always-free.md)), après la fin de l'essai prévue vers le 20 décembre 2026.

## Options envisagées

### Sous-réseau privé et passerelle NAT

La disposition la plus sûre, mais elle risque de cesser de fonctionner à la fin de l'essai. Elle obligerait aussi à passer en paiement à l'usage pour la garder.

### Une instance NAT

Un nœud avec une adresse publique fait du masquage d'adresses pour les autres. Il n'y a que deux nœuds et 2 OCPU : l'un des deux deviendrait un point unique de panne pour le trafic sortant de l'autre.

### Adresses publiques éphémères et filtrage strict

Les nœuds reçoivent une adresse publique éphémère et sortent directement par la passerelle Internet. La protection repose sur le filtrage en entrée plutôt que sur l'absence d'adresse.

## Décision

Adresses publiques éphémères et filtrage strict :

- la liste de sécurité par défaut, qui ouvre SSH à tout Internet, est vidée et rattachée à tous les sous-réseaux ;
- tout le filtrage passe par des groupes de sécurité réseau, un par rôle, sans aucune règle d'entrée depuis Internet sur les nœuds ;
- seul le load balancer accepte du trafic d'Internet, en HTTP et HTTPS ;
- l'accès SSH passe par le service Bastion d'Oracle (#16), jamais par un port ouvert.

## Conséquences

- Le cluster continue de sortir sur Internet après la fin de l'essai, sans dépendre d'une ressource payante.
- Chaque nœud a une adresse publique : une erreur dans un groupe de sécurité l'exposerait directement. Toute règle d'entrée sur les nœuds passe donc en revue de PR, et une vérification automatique devra le confirmer, par exemple un scan des ports depuis la CI.
- Les adresses publiques changent si une instance est recréée : rien ne doit en dépendre, ni DNS ni règle de pare-feu.
- Si Oracle confirme un jour que la passerelle NAT reste disponible, ou si la tenancy passe en paiement à l'usage, un nouvel ADR pourra rendre les nœuds privés : seul le module `network` serait touché.
