# 0021. Envoyer les alertes par courrier

- Statut : accepté
- Date : 2026-11-22

## Contexte

L'[ADR 0018](0018-alertes-avec-alertmanager-et-telegram.md) envoyait les alertes sur Telegram. Avant la mise en service, le propriétaire a préféré les recevoir dans sa boîte de courrier. Alertmanager a alors besoin d'un serveur d'envoi.

Les contraintes :

- aucun compte de plus à ouvrir ni mot de passe personnel à confier au cluster ;
- rester dans l'offre gratuite ([ADR 0008](0008-passer-en-paiement-a-l-usage-sous-quotas.md)) ;
- l'adresse du destinataire reste hors du dépôt, qui est public ;
- ne pas toucher au courrier du domaine `rtgre.fr`, hébergé chez OVH.

## Options envisagées

### Une boîte OVH du domaine

Le domaine a déjà ses boîtes. Mais Alertmanager porterait le mot de passe d'une boîte personnelle.

### Un service d'envoi tiers

Plusieurs ont une offre gratuite. Chacun demande un compte de plus, et ses propres enregistrements DNS.

### Email Delivery d'Oracle

Déjà dans la tenancy : 3 000 messages gratuits par mois. L'expéditeur, sa signature et son identifiant se décrivent en Terraform, à côté du reste.

### Envoi direct aux serveurs du destinataire

Aucun intermédiaire, mais Oracle ferme par défaut le port 25 en sortie.

## Décision

Email Delivery d'Oracle, depuis un sous-domaine réservé à l'envoi.

- **`alertes.rtgre.fr` n'envoie que les alertes.** Il a son SPF et sa clé DKIM ; ceux du domaine principal, et ses boîtes, ne changent pas.
- **Un utilisateur qui ne peut que cela** : toutes ses capacités sont retirées sauf l'identifiant SMTP. Il n'a ni mot de passe, ni clé d'API, ni accès à la console.
- **Un plafond de 100 messages par jour**, posé en quota : le mois reste sous les 3 000 messages gratuits, même si une alerte s'emballe.
- **Alertmanager ne peut joindre que le serveur d'envoi**, sur le port 587, en TLS.
- **L'identifiant SMTP et l'adresse du destinataire restent hors du dépôt.** `scripts/alertmanager-email.sh` les porte dans un Secret : le premier vient du state du bootstrap, la seconde d'un fichier du poste. Les conteneurs qui préparent la configuration d'Alertmanager les y placent.

## Conséquences

- Plus de bot à créer : la mise en service ne demande rien au propriétaire.
- Un courrier se lit moins vite qu'une notification. Une règle de sa boîte peut y remédier.
- Sans le Secret, Alertmanager ne démarre pas, alors qu'il tournait sans le jeton de Telegram : après une reconstruction du cluster, relancer le script ([runbook](../runbooks/recevoir-les-alertes.md)).
- Le mot de passe SMTP est dans le state du bootstrap, chiffré dans le bucket ([ADR 0020](0020-chiffrer-le-state-avec-une-cle-du-vault.md)).
- Oracle refuse un identifiant SMTP à un utilisateur de service : celui-ci est un utilisateur ordinaire, bridé. La politique lui donne l'usage de toute la famille du courrier, car l'usage des seuls expéditeurs ne suffit pas à envoyer ; sans clé d'API, il ne peut de toute façon rien appeler d'autre que le serveur SMTP.
- Un quota du courrier met plusieurs minutes à s'appliquer, et mettre la famille à zéro bloque tout envoi : elle porte aussi le débit.
- Les limites de l'ADR 0018 demeurent : les alertes partent du cluster qu'elles surveillent.
