# 0014. Journaux de visite sans adresse complète

- Statut : accepté
- Date : 2026-11-21

## Contexte

Sur GitHub Pages, rtgre ne voyait aucun visiteur : le site annonce « pas de serveur, pas de compte, pas de base de données ». Servi par le cluster, il passe par un serveur web qui peut tout journaliser, à commencer par l'adresse IP de chaque visiteur, qui est une donnée personnelle.

Il faut pourtant des journaux : pour diagnostiquer une panne, et pour savoir à peu près combien de personnes utilisent le site.

## Options envisagées

### Aucune adresse

C'était l'état du serveur à son déploiement. La promesse du site reste presque intacte, mais il devient impossible de distinguer dix visiteurs d'un seul qui recharge dix fois.

### L'adresse complète, anonymisée plus tard

Le serveur écrit l'adresse, et l'outil de collecte la tronque. L'adresse complète existe alors sur le disque du nœud, même brièvement, et la promesse ne tient qu'à un réglage de l'outil.

### Le réseau du visiteur, tronqué à l'écriture

Le serveur ne garde que le début de l'adresse : assez pour compter des visiteurs approximatifs, pas assez pour désigner une personne. L'adresse complète n'est jamais écrite.

## Décision

Seul le réseau du visiteur est journalisé, tronqué par nginx au moment d'écrire la ligne, et les journaux sont détruits chaque semaine.

- **Troncature** : les trois premiers octets en IPv4 (`203.0.113.0`, un /24, 256 adresses), les trois premiers groupes en IPv6 (`2001:db8:85a3::`, un /48). Une adresse qui ne se reconnaît pas est remplacée par un tiret.
- **Jamais écrite en entier, nulle part** :
  - le load balancer d'Oracle n'a aucun journal activé ;
  - Traefik reçoit l'adresse par le PROXY protocol et la transmet à nginx dans un en-tête, mais son journal des accès est désactivé ;
  - nginx ne l'a qu'en mémoire, le temps d'une requête.
- **Ce qui est journalisé** : la date, le réseau, la requête, le code de réponse, la taille, la page d'origine, le navigateur, la durée. Les sondes de kubelet ne le sont pas.
- **Conservation** : les journaux d'un pod disparaissent avec lui. Une tâche remplace le pod du serveur web chaque semaine, la nuit, sans coupure. Si un passage échoue, le suivant rattrape : aucun journal ne dépasse quatorze jours.
- **Moindre privilège** : cette tâche est le seul pod de l'espace de noms à recevoir un jeton de l'API de Kubernetes. Son seul droit est de modifier le déploiement du serveur web, et elle ne sort que vers l'API.
- **Sans `kubectl`** : son image officielle (v1.36.6) porte six vulnérabilités HIGH selon Trivy. Un script d'une trentaine de lignes, avec la seule bibliothèque standard de Python, fait le même appel depuis l'image officielle de Python, qui n'en porte aucune. Depuis le 21 novembre 2026, il tourne avec l'image du générateur du site, qui apporte Python : l'image officielle a reçu depuis cinq vulnérabilités HIGH, dans des paquets que le script n'utilise pas.

## Conséquences

- Le texte du site doit changer à la bascule : il y aura un serveur, qui garde le réseau des visiteurs pendant une à deux semaines. La modification se fait dans le dépôt rtgre, en même temps que le changement du DNS.
- Un réseau tronqué reste une donnée indirectement personnelle : la conservation courte fait partie de la décision, pas seulement la troncature.
- La collecte des journaux, en phase 5, devra respecter la même limite de quatorze jours, et ne rien ajouter qui identifie un visiteur.
- Le nombre de visiteurs sera approximatif : deux personnes derrière le même réseau, à l'IUT par exemple, n'en font qu'une.
- Diagnostiquer un abus venant d'une adresse précise n'est pas possible. Si le besoin apparaît, la réponse sera une limite de débit à la passerelle, pas un journal plus bavard.
