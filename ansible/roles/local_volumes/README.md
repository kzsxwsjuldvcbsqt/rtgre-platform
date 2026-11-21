# Rôle `local_volumes`

Crée sur un nœud les dossiers des volumes persistants locaux ([ADR 0011](../../../docs/adr/0011-stocker-sur-des-volumes-locaux-statiques.md)).

Les volumes ne sont déclarés qu'à un endroit, [`kubernetes/storage/values.yaml`](../../../kubernetes/storage/values.yaml). L'inventaire en tire `local_volumes_directory` et, pour chaque nœud, `local_volumes_names` : les volumes dont il est le `node`. Argo CD tire du même fichier les PersistentVolume correspondants.

| Dossier | Droits |
| --- | --- |
| `local_volumes_directory` | `root:root`, `0711` : traversable, sans que son contenu se liste |
| un sous-dossier par volume | `root:root`, `0770` à la création |

## Choix notables

- **Le rôle ne reprend jamais les droits d'un volume existant** : au premier montage, kubelet donne le volume au groupe du pod (`fsGroup`). Si le rôle les remettait à chaque passage, l'application perdrait l'accès à ses données jusqu'à son prochain redémarrage.
- **Un volume retiré du fichier n'est pas supprimé** : ses données restent sur le nœud. La suppression est manuelle, voir le [README de `kubernetes/storage`](../../../kubernetes/storage/README.md).

## Tests

Le scénario Molecule vérifie les droits du dossier parent et d'un nouveau volume, et qu'un volume déjà donné à un pod garde son groupe.
