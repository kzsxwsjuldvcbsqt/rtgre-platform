# 0013. Certificats par cert-manager et Let's Encrypt

- Statut : accepté
- Date : 2026-11-21

## Contexte

La passerelle termine le TLS dans le cluster ([ADR 0012](0012-exposer-par-un-network-load-balancer-et-gateway-api.md)). Il lui faut des certificats reconnus par les navigateurs, obtenus et renouvelés sans intervention : ceux de Let's Encrypt ne durent que trois mois.

Les contraintes :

- des routes en Gateway API, portables d'un contrôleur à l'autre ;
- aucun secret d'un service extérieur dans le cluster, si possible ;
- le même refus par défaut des entrées et des sorties que pour les autres composants.

## Options envisagées

### Le client ACME de Traefik

Aucun composant de plus. Mais il ne délivre de certificats qu'à ses propres routes (IngressRoute) ou à ses points d'entrée, pas aux écoutes d'une Gateway : il faudrait sortir de Gateway API, et lier les certificats à Traefik.

### cert-manager, défi DNS-01

Le certificat s'obtient avant même que le nom désigne le cluster, et peut couvrir un nom générique. Mais OVH n'est pas un fournisseur intégré : il faut un webhook tiers, et des clés d'API d'OVH dans le cluster, capables de modifier la zone.

### cert-manager, défi HTTP-01

Let's Encrypt vérifie le nom en HTTP, à travers la passerelle. Aucun secret extérieur. En contrepartie, le nom doit déjà désigner le cluster quand le certificat est demandé.

## Décision

cert-manager 1.21, avec le défi HTTP-01 à travers la passerelle.

- **Deux émetteurs** : celui de test de Let's Encrypt, pour valider une modification sans risquer les limites de l'émetteur de production, et celui de production.
- **Un certificat pour tous les noms publics**, déclaré dans le chart de la passerelle, à côté de l'écoute HTTPS qui le lit. Sa clé change à chaque renouvellement.
- **Tout le HTTP est redirigé vers HTTPS** par une route de la passerelle. Les routes des défis, plus précises, passent avant elle.
- **HSTS** sur le site, à la valeur que GitHub Pages donnait déjà.
- **Sorties filtrées par nom** : le contrôleur ne joint que les deux annuaires de Let's Encrypt, en HTTPS, et les noms de la zone, en HTTP, pour vérifier un défi avant de le soumettre. Le webhook ne reçoit que l'API de Kubernetes.
- **Mesure** (`scripts/measure-node.sh wk-1 60`, au repos) : environ 75 Mo pour les trois composants.

## Conséquences

- Ajouter un nom public demande qu'il désigne déjà le load balancer. À la bascule de rtgre.fr, le certificat ne pourra donc être demandé qu'après le changement du DNS : pendant la minute que prend son émission, le cluster présentera un certificat qui ne couvre pas ce nom. La bascule devra en tenir compte.
- Un seul nom en échec bloque tout le certificat : un nom retiré du DNS doit d'abord être retiré du certificat.
- **Vulnérabilités connues** : les images de cert-manager 1.21.3 portent deux à trois vulnérabilités HIGH selon Trivy, toutes des dénis de service (bibliothèque standard de Go, `golang.org/x/net`, `go-jose`). Aucun de ses pods n'est joignable d'Internet, sauf le pod d'un défi, pendant les quelques secondes d'une émission. Les correctifs sont déjà fusionnés dans sa branche de maintenance : la version suivante les apportera, et Renovate la proposera. Suivi dans #73.
- L'expiration du certificat n'est pas encore surveillée : une alerte viendra avec l'observabilité (phase 5). D'ici là, le [runbook](../runbooks/suivre-les-certificats.md) montre comment la lire.
