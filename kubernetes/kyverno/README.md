# Contrôle des images à l'admission

Dans les espaces de noms étiquetés `rtgre.fr/verified-images: required`, le cluster refuse lui-même un pod dont l'image n'est pas celle attendue, même si la CI a été contournée ([ADR 0019](../../docs/adr/0019-controler-les-images-a-l-admission-avec-kyverno.md)). Aujourd'hui : l'espace de noms `rtgre`.

| Contrôle | Qui l'applique | Ce qu'il refuse |
| --- | --- | --- |
| Dépôt déclaré et empreinte | L'API de Kubernetes, par une politique native ([`declared-images`](templates/declared-images.yaml)) | Une image d'un dépôt absent des deux listes ci-dessous, ou référencée par un tag seul |
| Signature | Kyverno ([`signed-images`](templates/signed-images.yaml)) | Une image d'un dépôt à signature exigée qui n'est pas signée par l'identité attendue |

Les deux listes :

- [`files/signed-images.txt`](files/signed-images.txt) : dépôts dont les images doivent être signées, et par qui. La CI applique la même liste avant toute fusion (`scripts/ci/verify-image-signatures.sh`).
- `unsignedImages`, dans [`values.yaml`](values.yaml) : dépôts admis sans signature, parce que leur éditeur ne signe pas.

Seul le contrôleur d'admission de Kyverno est déployé. Il n'est appelé que pour les espaces de noms étiquetés, et ne peut joindre que le registre des images signées et Sigstore.

## Ajouter une image à un espace de noms contrôlé

- Son éditeur la signe avec cosign, sans clé : ajouter une ligne à `files/signed-images.txt`, et le nom du registre à `egress.hosts` s'il n'y est pas.
- Sinon : ajouter son dépôt à `unsignedImages`.

Dans les deux cas, la référencer par son empreinte.

## Contrôler un espace de noms de plus

Ajouter l'étiquette à ses `namespaceLabels`, dans [`apps/values.yaml`](../apps/values.yaml). Vérifier d'abord que toutes ses images sont dans l'une des deux listes : sinon ses pods ne seront plus recréés.

## Un pod est refusé

Le refus apparaît dans les événements de l'objet qui crée le pod :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre get events --field-selector type=Warning --sort-by=.lastTimestamp
```

| Message | Cause | Que faire |
| --- | --- | --- |
| `image d'un dépôt non déclaré, ou sans empreinte` | L'image n'est dans aucune des deux listes, ou n'a qu'un tag. | L'ajouter à une liste, ou lui donner son empreinte. |
| `no signatures found` | L'image n'est pas signée. | Elle n'a pas été publiée par son workflow officiel : ne pas la déployer. |
| `no matching CertificateIdentity found` | Elle est signée, mais par un autre workflow ou une autre branche. | Même réponse. Si le workflow a été renommé, corriger `files/signed-images.txt`. |
| `failed to get imagedata … i/o timeout` | Kyverno ne joint pas le registre. | Le registre est en panne, ou son nom manque dans `egress.hosts`. |
| `failed calling webhook … kyverno-svc` | Kyverno ne répond pas. | Voir ci-dessous. |

## Kyverno ne répond pas

Tant qu'il est arrêté, aucun pod ne peut être créé dans un espace de noms contrôlé : la vérification refuse plutôt que de laisser passer. Les pods qui tournent continuent, donc le site reste servi, mais il n'est plus régénéré, et un serveur web qui s'arrêterait ne serait pas remplacé. Les autres espaces de noms ne sont pas touchés.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n kyverno get pods
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n kyverno logs deploy/kyverno-admission-controller --tail 50
```

Voir [diagnostiquer-un-pod](../../docs/runbooks/diagnostiquer-un-pod.md). En urgence, si le site est en panne et que Kyverno ne repart pas, retirer son webhook rend la création des pods possible, sans vérification de signature. La politique native continue de s'appliquer, et Kyverno recrée son webhook en redémarrant.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg
```

## Mettre à jour Kyverno

Renovate propose les nouvelles versions du chart ; une montée mineure ou majeure attend une approbation. Le chart prévoit des tâches de migration que Helm lance avant une mise à jour : elles sont désactivées ici, car Argo CD n'installe pas par Helm. Avant d'approuver, lire les notes de la version, puis essayer la branche sur le cluster ([README de `kubernetes`](../README.md)).

## Retirer Kyverno

Retirer l'application ne supprime rien. Kyverno crée lui-même ses webhooks : sans lui, ils resteraient en place et bloqueraient les espaces de noms contrôlés. Dans l'ordre :

1. Retirer l'étiquette des espaces de noms contrôlés, dans `apps/values.yaml`.
2. Retirer l'application, puis supprimer ses webhooks, son espace de noms et ses CRD :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -o name | grep kyverno | xargs kubectl delete"
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl delete namespace kyverno
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl get crd -o name | grep kyverno.io | xargs kubectl delete"
```

## Choix notables

- **Deux contrôles, deux moteurs** : la liste des dépôts ne demande aucun accès au réseau, l'API de Kubernetes l'évalue seule et continue de le faire si Kyverno est arrêté. Seule la signature demande Kyverno.
- **Refuser plutôt que laisser passer** : si la vérification est impossible, le pod est refusé.
- **Aucune réécriture** : un tag n'est pas remplacé par son empreinte à la volée. C'est le dépôt qui la porte, et la CI qui l'exige.
- **Un seul pod** : ni rapports, ni analyse en arrière-plan, ni nettoyage. Mesuré à 57 Mo au repos.
