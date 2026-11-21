# Volumes persistants

Volumes locaux statiques ([ADR 0011](../../docs/adr/0011-stocker-sur-des-volumes-locaux-statiques.md)) : aucun approvisionneur ne tourne dans le cluster, un volume n'existe que s'il est déclaré dans [`values.yaml`](values.yaml).

## Ajouter un volume

1. Ajouter une entrée sous `volumes` : son nom, le nœud qui le porte, sa taille indicative et la seule demande autorisée à s'y lier.
2. Lancer le playbook : le rôle [`local_volumes`](../../ansible/roles/local_volumes) crée le dossier sur le nœud.
3. Fusionner : Argo CD crée le PersistentVolume.

Dans l'application, la demande reprend la classe `local` et le nom déclaré. Ses pods fixent un `fsGroup` : au montage, kubelet donne le volume à ce groupe. Deux pods d'utilisateurs différents partagent un volume en prenant le même `fsGroup`.

## Libérer un volume

Quand une demande est supprimée, son volume passe à l'état `Released` : ses données sont conservées, et il reste réservé à l'ancienne demande. Une nouvelle demande du même nom resterait en attente. Pour le rendre de nouveau disponible, avec ses données :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl patch pv <nom> --type json -p '[{\"op\":\"remove\",\"path\":\"/spec/claimRef/uid\"},{\"op\":\"remove\",\"path\":\"/spec/claimRef/resourceVersion\"}]'"
```

Le volume repasse à `Available`, et la demande suivante s'y lie.

## Retirer un volume

Retirer l'entrée supprime le PersistentVolume, pas le dossier. Les données restent sur le nœud, dans `directory/<nom>`, jusqu'à leur suppression à la main.
