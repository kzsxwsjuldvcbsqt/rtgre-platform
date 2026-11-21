# 0012. Exposer par un Network Load Balancer et Gateway API

- Statut : accepté
- Date : 2026-11-21

## Contexte

Le site tourne dans le cluster, mais rien n'y entre depuis Internet. Deux choix sont à faire : par où le trafic arrive jusqu'aux nœuds, et ce qui le route ensuite vers les applications.

Les contraintes :

- rester dans l'offre gratuite d'Oracle, qui comprend un Load Balancer limité à 10 Mbps et un Network Load Balancer ;
- des nœuds qui ont une adresse publique ([ADR 0006](0006-sortir-par-la-passerelle-internet-sans-nat.md)) : leurs ports ne doivent pas s'ouvrir à Internet ;
- un seul nœud de travail, de 6 Go ([ADR 0003](0003-monter-kubernetes-avec-kubeadm.md)) ;
- connaître l'adresse du client, pour la journaliser tronquée ;
- ingress-nginx, le contrôleur que prévoyait le plan, n'est plus maintenu depuis mars 2026, et l'API Ingress n'évolue plus : Gateway API la remplace.

## Options envisagées

### Entrée : Load Balancer d'Oracle

Il termine le TLS et route le HTTP lui-même. Mais les certificats devraient lui être fournis, donc sortir du cluster ou être renouvelés à la main, et son débit gratuit est limité à 10 Mbps.

### Entrée : Network Load Balancer d'Oracle

Il transmet des connexions TCP sans les déchiffrer. Les certificats restent dans le cluster. Il peut transmettre l'adresse du client par le PROXY protocol.

### Routage : Gateway API de Cilium

Aucun composant de plus : Cilium est déjà là. Mais sa Gateway API exige de remplacer kube-proxy, que l'[ADR 0009](0009-reseau-des-pods-avec-cilium.md) a choisi de garder. Ce serait changer le réseau de tout le cluster pour exposer un site.

### Routage : Envoy Gateway

Implémentation de référence du projet Envoy. Elle demande deux composants, un contrôleur et des proxys Envoy, et Trivy relève une vulnérabilité HIGH dans l'image du contrôleur (v1.10.0).

### Routage : Traefik

Un seul pod, qui fait contrôleur et proxy. Il est conforme à Gateway API (canal standard, v1.6.3), sait recevoir le PROXY protocol, et Trivy ne relève aucune vulnérabilité dans son image (v3.7.19).

## Décision

Le Network Load Balancer gratuit devant le nœud de travail, et Traefik comme contrôleur Gateway API.

- **Le load balancer se présente aux nœuds avec sa propre adresse.** Le groupe de sécurité des nœuds n'accepte donc le trafic web que de lui : les ports des nœuds restent fermés à Internet. L'adresse du client est transmise par le PROXY protocol v2, que Traefik n'accepte que du sous-réseau du load balancer.
- **Deux ports seulement** : 80 et 443, vers deux ports fixes des nœuds (NodePort), en `externalTrafficPolicy: Local` pour que l'adresse du load balancer ne soit pas masquée.
- **Le TLS se termine dans Traefik**, avec les certificats que cert-manager gérera dans le cluster.
- **Traefik ne sert que Gateway API** : ses fournisseurs Ingress et IngressRoute sont désactivés, ses propres CRD ne sont pas installées. Les routes sont des objets standard, portables vers un autre contrôleur.
- **Les CRD de Gateway API** viennent du dépôt officiel, à la version que Traefik prend en charge, épinglée par son commit.
- **Quotas** : tout Load Balancer est interdit dans la tenancy, et un seul Network Load Balancer est permis.

## Conséquences

- Une application s'expose avec une HTTPRoute dans son propre chart ; la passerelle choisit les espaces de noms autorisés à s'y attacher.
- Deux valeurs sont écrites à deux endroits, faute de lien entre Terraform et le cluster : les ports des nœuds et la plage du sous-réseau du load balancer. Chaque fichier renvoie à l'autre.
- L'adresse publique du load balancer est éphémère : elle change s'il est recréé. La zone DNS la lira dans les sorties de Terraform.
- Le nœud de travail reste un point de défaillance unique : le load balancer ne fait que le constater par sa sonde.
- Une version de Gateway API se change avec celle de Traefik, jamais seule.
- Si kube-proxy est un jour remplacé par Cilium, sa Gateway API permettrait de retirer Traefik : les routes n'auraient pas à changer.
