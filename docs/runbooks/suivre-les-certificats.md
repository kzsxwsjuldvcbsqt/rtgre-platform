# Suivre les certificats

Le certificat des noms publics est obtenu et renouvelé par cert-manager ([ADR 0013](../adr/0013-certificats-par-cert-manager-et-lets-encrypt.md)). Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

Deux alertes y renvoient : `CertificatNonPret`, quand cert-manager échoue depuis une heure, et `CertificatExpireBientot`, à quatorze jours de l'expiration. Pour l'une comme pour l'autre, commencer par « Un certificat n'arrive pas ». Elles couvrent aussi les certificats internes de l'espace de noms `monitoring` : remplacer alors `gateway` et `public` par l'espace de noms et le nom que donne l'alerte.

## Voir l'état

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n gateway get certificate public -o wide
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n gateway get certificate public -o jsonpath='expire {.status.notAfter}, renouvellement prévu {.status.renewalTime}'"
```

`READY` doit valoir `True`. cert-manager renouvelle de lui-même à la date prévue, un mois avant l'expiration.

Depuis n'importe quel poste, le certificat réellement servi :

```bash
echo | openssl s_client -connect test.rtgre.fr:443 -servername test.rtgre.fr 2>/dev/null | openssl x509 -noout -issuer -dates
```

## Forcer un renouvellement

Pour vérifier la chaîne sans attendre l'échéance, ou après avoir corrigé une panne :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n gateway patch certificate public --subresource=status --type=merge -p '{\"status\":{\"conditions\":[{\"type\":\"Issuing\",\"status\":\"True\",\"reason\":\"ManuallyTriggered\",\"message\":\"Renouvellement demandé à la main\",\"lastTransitionTime\":\"'\$(date -u +%Y-%m-%dT%H:%M:%SZ)'\"}]}}'"
```

En une minute, `status.revision` augmente de un, et Traefik sert le nouveau certificat sans redémarrer.

## Ajouter un nom

1. Le nom doit d'abord désigner le load balancer : l'ajouter à `cluster_subdomains` dans [`terraform/dns`](../../terraform/dns), et appliquer.
2. L'ajouter à `certificate.dnsNames` dans `kubernetes/gateway/values.yaml`, et aux `hostnames` de l'application qui le sert.

Pour une modification risquée, passer d'abord `certificate.issuer` à `letsencrypt-staging` : l'émetteur de test a des limites larges. Son certificat n'est pas reconnu par les navigateurs.

## Un certificat n'arrive pas

La demande passe par quatre objets, à lire dans cet ordre :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n gateway get certificate,certificaterequest,order,challenge
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n gateway describe challenge
```

| Message du défi | Cause | Que faire |
| --- | --- | --- |
| `Waiting for HTTP-01 challenge propagation: wrong status code` | Le nom ne désigne pas le load balancer, ou la passerelle ne répond pas. | Vérifier le DNS du nom, puis les sondes du load balancer. |
| `no such host` ou erreur DNS | Le nom n'existe pas dans la zone. | L'ajouter au DNS, ou le retirer du certificat : un seul nom en échec bloque tout. |
| `too many certificates` | Limite de l'émetteur de production atteinte. | Attendre, et valider avec l'émetteur de test. |

Tant que le renouvellement échoue, le certificat en place reste servi jusqu'à son expiration : il reste un mois pour corriger.
