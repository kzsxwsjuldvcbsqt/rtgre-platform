# 0026. Sauvegarder la base d'Umami avec l'identité des nœuds

- Statut : accepté
- Date : 2026-11-22

## Contexte

La base d'Umami vit sur un volume local du nœud de travail ([ADR 0011](0011-stocker-sur-des-volumes-locaux-statiques.md)) : elle disparaît avec lui. La reconstruction du 22 novembre 2026 a emporté les métriques et les journaux, ce qui était accepté. Un historique d'audience voulu sur la durée ne peut pas suivre le même sort ([ADR 0025](0025-mesurer-l-audience-avec-umami.md)).

Les contraintes :

- la sauvegarde sort du cluster, et de ses nœuds ;
- aucun secret à longue durée de vie n'entre dans le cluster pour cela ;
- un nœud compromis ne doit pouvoir ni lire ni détruire les sauvegardes déjà faites ;
- tout reste dans l'offre gratuite.

## Options envisagées

### Sauvegarder le volume de démarrage du nœud

Oracle sauvegarde un volume entier. Cinq sauvegardes sont gratuites, pour deux nœuds. La restauration rend un disque, pas une base : il faudrait le monter ailleurs pour en extraire les données.

### Une clé d'API ou une adresse pré-authentifiée, dans un Secret

Un utilisateur d'Oracle limité au bucket, dont la clé serait déposée dans le cluster, ou une adresse pré-authentifiée en écriture seule. Dans les deux cas, un secret qui dure, à déposer hors du dépôt et à renouveler.

### L'identité des nœuds

Chaque instance d'Oracle a une identité, que son service de métadonnées échange contre un jeton de courte durée. Une politique donne à cette identité des droits, sans qu'aucun secret n'existe.

## Décision

Un CronJob du chart `umami` exporte la base chaque nuit avec `pg_dump`, puis `rclone` dépose le fichier dans un bucket d'Object Storage, avec l'identité du nœud.

- **Un bucket réservé aux sauvegardes**, privé, chiffré par sa propre clé du Vault ([ADR 0020](0020-chiffrer-le-state-avec-une-cle-du-vault.md)), créé par le bootstrap et protégé contre la suppression.
- **Les nœuds déposent, et rien d'autre.** Leur identité peut créer un objet dans ce seul bucket et en voir la liste. Elle ne peut ni lire un objet, ni le remplacer, ni le supprimer.
- **Object Storage purge lui-même** : une règle du bucket supprime les sauvegardes après trente jours.
- **Le service de métadonnées est fermé aux pods.** Une règle réseau du cluster en refuse l'accès à tout pod qui ne porte pas l'étiquette `rtgre.fr/instance-identity`. Seul le pod de sauvegarde la porte. Elle ne refuse que le port 80 : la même adresse est aussi le résolveur DNS d'Oracle.
- **La restauration se fait du poste**, avec les droits de son propriétaire : le cluster n'a pas de quoi lire une sauvegarde.
- **Une alerte** part quand aucune sauvegarde n'a réussi depuis deux jours.

## Conséquences

- Vérifié depuis un pod, avec l'identité du nœud : le dépôt et la liste réussissent ; la lecture, le remplacement, la suppression et l'accès au bucket du state sont refusés.
- **L'identité est celle du nœud, pas celle du pod.** Un pod qui tourne sur le réseau de son nœud, ou quiconque peut poser l'étiquette sur un pod, obtient le même droit de dépôt. Il ne peut que remplir le bucket, que le quota d'Object Storage borne ([ADR 0008](0008-passer-en-paiement-a-l-usage-sous-quotas.md)).
- Vérifié aussi : une sauvegarde téléchargée du bucket a été rejouée dans la base en service, sans perte.
- **Une règle qui vaut pour tout le cluster peut tout couper.** Sa première version refusait l'adresse entière, et le cluster n'a plus résolu aucun nom externe pendant huit minutes, à l'essai ([post-mortem](../postmortems/2026-11-22-noms-externes-non-resolus-dans-le-cluster.md)).
- Un jour de mesures au plus est perdu : ce qui suit la dernière sauvegarde.
- Le nom du bucket et le namespace Object Storage, propres à la tenancy, restent hors du dépôt : `scripts/umami-backup-config.sh` les porte au cluster, et se relance après une reconstruction.
- La sauvegarde contient les comptes du tableau de bord et l'empreinte de leur mot de passe. Les restaurer ramène ces comptes tels qu'ils étaient.
- Les autres volumes ne sont pas sauvegardés : les métriques et les journaux restent des données que l'on accepte de perdre.
