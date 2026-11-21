# cert-manager

Obtient et renouvelle les certificats de la passerelle auprès de Let's Encrypt ([ADR 0013](../../docs/adr/0013-certificats-par-cert-manager-et-lets-encrypt.md)).

| Objet | Rôle |
| --- | --- |
| ClusterIssuer `letsencrypt-staging` | Émetteur de test : certificats non reconnus, limites larges |
| ClusterIssuer `letsencrypt-production` | Émetteur de production : certificats reconnus par les navigateurs |
| NetworkPolicy, CiliumNetworkPolicy | Le contrôleur ne joint que Let's Encrypt et les noms de la zone ; le webhook ne reçoit que l'API de Kubernetes |

Le certificat lui-même n'est pas ici : il est déclaré avec l'écoute HTTPS qui le lit, dans le chart [`gateway`](../gateway).

## Comment un certificat est obtenu

```mermaid
sequenceDiagram
    participant C as cert-manager
    participant L as Let's Encrypt
    participant G as Passerelle
    C->>L: demande un certificat pour un nom
    L-->>C: défi : servir un jeton sur ce nom, en HTTP
    C->>G: crée un pod et une route éphémères pour le jeton
    C->>G: vérifie lui-même que le jeton répond
    L->>G: lit le jeton depuis Internet
    L-->>C: certificat
    C->>G: range le certificat dans le Secret de l'écoute HTTPS
```

Le pod et la route du défi vivent quelques secondes, dans l'espace de noms de la passerelle.

## Choix notables

- **Défi HTTP-01** : aucun secret extérieur dans le cluster. Le nom doit déjà désigner le load balancer.
- **Sans adresse de contact** : Let's Encrypt n'en demande pas.
- **Tout dans son espace de noms**, y compris l'élection du composant actif, que le chart place par défaut dans `kube-system`.
- **Retirer l'application ne supprime rien** : ses CRD emporteraient les certificats.

## Exploitation

Voir le runbook [suivre-les-certificats](../../docs/runbooks/suivre-les-certificats.md).
