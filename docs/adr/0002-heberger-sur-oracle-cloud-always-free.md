# 0002. Héberger sur Oracle Cloud Always Free

- Statut : accepté
- Date : 2026-11-20

## Contexte

rtgre.fr est un site statique reconstruit toutes les heures à partir des flux iCalendar d'ADE. Il est aujourd'hui servi par GitHub Pages. La plateforme doit le faire tourner sur un cluster Kubernetes d'au moins deux nœuds, avec la supervision qui va avec.

Contraintes :

- budget nul, ou de quelques euros par mois au plus ;
- durée de vie de plus d'un an, donc sans crédits d'essai qui expirent ;
- un fournisseur pris en charge par un provider Terraform maintenu ;
- des données hébergées en Europe.

## Options envisagées

### Oracle Cloud Infrastructure, offre Always Free

Gratuite sans limite de durée. Selon la [documentation](https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm) consultée le 2026-11-20 :

- Ampere A1 (ARM) : 2 OCPU et 12 Go de mémoire au total, en une instance ou deux instances de 1 OCPU ;
- deux instances AMD de 1/8 d'OCPU et 1 Go, trop petites pour un nœud Kubernetes ;
- 200 Go de stockage bloc, volumes de démarrage compris ;
- 20 Go de stockage objet ;
- un load balancer flexible à 10 Mbit/s et un network load balancer ;
- 10 To de trafic sortant par mois.

Oracle a réduit ces limites le 15 juin 2026 : elles étaient de 4 OCPU et 24 Go. D'après des échanges avec le support, [rapportés par InfoQ](https://infoq.com/news/2026/07/oracle-cloud-free-tier-limits/), les comptes passés en paiement à l'usage garderaient 4 OCPU et 24 Go sans frais. Oracle ne l'a pas confirmé publiquement.

Inconvénients : le fournisseur est moins répandu en entreprise qu'AWS ou Azure, la capacité ARM est parfois épuisée dans une région, et les instances jugées inactives peuvent être récupérées.

### AWS ou Azure avec crédits

Les deux fournisseurs les plus demandés. Leurs offres gratuites reposent sur des crédits ou une durée limitée : au-delà, deux petites VM coûtent plusieurs dizaines d'euros par mois.

### Hetzner Cloud

Environ 4 € par mois pour une petite VM ARM, ce qui est simple et fiable. Mais ce n'est pas gratuit, et c'est un hébergeur plutôt qu'un cloud complet : pas d'IAM fin, pas de stockage objet géré équivalent.

### Serveur personnel

Gratuit si le matériel existe déjà, mais il dépend d'une connexion domestique. Il n'exerce pas non plus les compétences cloud visées : IAM, réseau virtuel, API du fournisseur.

## Décision

Oracle Cloud Infrastructure, dans la région Paris (`eu-paris-1`), avec les ressources Always Free uniquement. C'est la seule option gratuite dans la durée qui offre un vrai cloud : IAM, réseau virtuel, load balancer et stockage objet, tous pilotables par Terraform.

## Conséquences

- La plateforme est dimensionnée pour 2 OCPU et 12 Go. Le nombre et la taille des nœuds sont des variables Terraform, pour suivre un changement des limites sans réécrire de code.
- Toutes les images doivent exister en `linux/arm64`. L'image de rtgre sera construite en multi-architecture.
- Une alerte de budget prévient dès le premier euro dépensé, pour détecter une ressource sortie de l'offre gratuite.
- Oracle considère une instance comme inactive quand, sur 7 jours, le CPU (95e percentile), le réseau et la mémoire restent tous sous 20 %. Un nœud Kubernetes dépasse ce seuil de mémoire, mais la mesure est à surveiller.
- La région de rattachement d'un compte Oracle ne peut plus être changée : le choix de Paris est définitif.
- Les compétences Terraform, Ansible et Kubernetes restent transférables. Seuls les modules qui appellent le provider `oci` sont propres à Oracle.
