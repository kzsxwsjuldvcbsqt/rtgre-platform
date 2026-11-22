# Sauvegarder et restaurer la base d'Umami

La base d'Umami est exportée chaque nuit, à 2 h 20, par le CronJob `umami-backup`, et déposée dans le bucket des sauvegardes, hors du cluster ([ADR 0026](../adr/0026-sauvegarder-la-base-d-umami-avec-l-identite-des-noeuds.md), [README de `kubernetes/umami`](../../kubernetes/umami/README.md)). Oracle supprime les sauvegardes de plus de trente jours.

L'alerte `SauvegardeTropAncienne` part quand aucune sauvegarde n'a réussi depuis deux jours : commencer par « Une sauvegarde échoue ».

Les commandes du cluster passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)). Celles d'Oracle se lancent du poste, depuis la racine du dépôt, avec le profil du bootstrap ([README](../../terraform/bootstrap/README.md)) : le cluster n'a pas le droit de lire une sauvegarde.

## Voir l'état

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami get cronjob,jobs
```

Le dernier Job est `Complete`. Le cluster garde la dernière réussite et les trois derniers échecs.

Les sauvegardes déposées, la plus récente en dernier :

```bash
storage_namespace=$(terraform -chdir=terraform/bootstrap output -raw objectstorage_namespace)
bucket=$(terraform -chdir=terraform/bootstrap output -raw backup_bucket)
oci os object list --namespace "$storage_namespace" --bucket-name "$bucket" --prefix umami/ \
  --query 'data[].{nom:name, octets:size}' --output table
```

Chaque objet porte la date et l'heure de sa sauvegarde, en temps universel : `umami/umami-20261122T012000Z.dump`.

## Lancer une sauvegarde sans attendre

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami create job --from=cronjob/umami-backup sauvegarde-manuelle
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami wait job/sauvegarde-manuelle --for=condition=complete --timeout=600s
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami delete job sauvegarde-manuelle
```

## Une sauvegarde échoue

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami get pods -l app.kubernetes.io/name=umami-backup
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami logs job/<nom du job> --all-containers
```

| Ce qui s'affiche | Cause | Que faire |
| --- | --- | --- |
| Le pod reste en `CreateContainerConfigError` | Le ConfigMap `umami-backup` manque : il ne vit pas dans le dépôt. | `scripts/umami-backup-config.sh` |
| `dump` : `connection to server … failed` | La base ne répond pas. | Voir le pod `umami-postgres-0` ([diagnostiquer-un-pod](diagnostiquer-un-pod.md)). |
| `upload` : `BucketNotFound` | Oracle refuse le dépôt : l'identité du nœud n'en a pas le droit, ou le ConfigMap désigne un autre bucket. | Relancer `scripts/umami-backup-config.sh`, puis vérifier que le plan du bootstrap est vide. Un droit tout juste créé met quelques minutes à s'appliquer. |
| `upload` : `i/o timeout`, `no such host`, ou aucune réponse | Le pod ne joint pas le service de métadonnées ou Oracle. | Vérifier qu'un pod résout encore un nom externe ([post-mortem](../postmortems/2026-11-22-noms-externes-non-resolus-dans-le-cluster.md)). Si la région a changé, corriger `backup.region` dans `kubernetes/umami/values.yaml`, d'où viennent les noms que la règle réseau autorise. |
| `upload` : le Job échoue sans rien avoir transféré | Une sauvegarde du même nom existe déjà : le pod n'a pas le droit de la remplacer. | Rien : la suivante porte une autre heure. |

## Restaurer

À faire après une reconstruction du cluster, une fois Umami démarré sur sa base neuve ([reconstruire-la-plateforme](reconstruire-la-plateforme.md)), ou pour revenir à un état antérieur. **La restauration remplace tout le contenu de la base** : ce qui a été mesuré depuis la sauvegarde choisie est perdu.

1. Télécharger la sauvegarde choisie sur le poste :

   ```bash
   storage_namespace=$(terraform -chdir=terraform/bootstrap output -raw objectstorage_namespace)
   bucket=$(terraform -chdir=terraform/bootstrap output -raw backup_bucket)
   oci os object get --namespace "$storage_namespace" --bucket-name "$bucket" \
     --name umami/<nom de la sauvegarde> --file umami.dump
   ```

2. La rejouer dans la base. Tout se fait en une transaction : en cas d'erreur, la base reste telle qu'elle était.

   ```bash
   ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami exec -i umami-postgres-0 -- \
     pg_restore --username=umami --dbname=umami --clean --if-exists --no-owner --single-transaction < umami.dump
   ```

3. Redémarrer Umami, qui applique les migrations de sa version si elle est plus récente que la sauvegarde. La collecte ne répond pas pendant quelques secondes :

   ```bash
   ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami rollout restart deployment/umami
   ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n umami rollout status deployment/umami
   ```

4. Ouvrir le tableau de bord et vérifier que l'historique est là. Les comptes sont ceux de la sauvegarde, avec leur mot de passe d'alors.

5. Supprimer le fichier du poste : il contient les comptes du tableau de bord.

   ```bash
   rm umami.dump
   ```

## Historique

- **22 novembre 2026** : première sauvegarde, de 72 Ko, puis restauration jouée sur la base en service avec le fichier téléchargé du bucket. Les mêmes sept événements et trois visites avant et après.
