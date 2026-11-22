# Mesure d'audience

Umami compte les visites du site, sans cookie, et garde l'historique dans sa base PostgreSQL ([ADR 0025](../../docs/adr/0025-mesurer-l-audience-avec-umami.md)).

| Composant | Rôle |
| --- | --- |
| Umami | Reçoit les visites envoyées par le script, et affiche le tableau de bord |
| PostgreSQL | Garde les données, sur un volume local déclaré dans [`storage`](../storage) |

## Ce qui est exposé

Deux chemins seulement, sous le nom du site :

| Chemin public | Ce que c'est |
| --- | --- |
| `/mesure.js` | Le script que charge chaque page, que la passerelle réécrit vers celui d'Umami |
| `/api/send` | Le point où le script envoie chaque visite |

Le tableau de bord et le reste d'Umami n'ont aucune route : ils ne sont pas joignables d'Internet.

## Mettre en service

Après le premier déploiement, ou après une reconstruction du cluster, depuis la racine du dépôt :

```bash
scripts/umami-secret.sh
```

Le script crée le Secret `umami` : le mot de passe de la base et la clé des sessions, tirés au hasard. Les pods démarrent dans la minute. Il ne fait rien si le Secret existe.

## Ouvrir le tableau de bord

Après avoir ouvert les sessions du Bastion ([se-connecter-a-un-noeud](../../docs/runbooks/se-connecter-a-un-noeud.md)) :

```bash
ssh -t -F ansible/.ssh/bastion.conf -L 8080:127.0.0.1:8080 cp-1 kubectl -n umami port-forward svc/umami 8080:3000
```

Puis ouvrir <http://localhost:8080>. Si le port 8080 est pris sur le poste, changer le premier nombre. À la première connexion, le compte est `admin` et son mot de passe est celui que documente Umami : le changer aussitôt, dans « Profile ».

## Déclarer un site

Dans le tableau de bord, « Settings », « Websites », « Add website ». L'identifiant affiché se place dans la configuration du site, qui charge alors `/mesure.js` avec lui (dépôt rtgre).

## Choix notables

- **La collecte passe par le nom du site** : la politique de sécurité du site n'autorise que lui, et aucun nom de plus n'est à certifier.
- **Umami ne sort que vers sa base** : sa base de localisation est dans son image, et ses statistiques d'usage sont coupées.
- **La base n'est pas encore sauvegardée** hors du cluster : suivi dans #115.
