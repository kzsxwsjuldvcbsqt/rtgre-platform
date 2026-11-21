# Le site ne répond plus

Alerte `SiteInjoignable` : la sonde du cluster n'obtient plus de réponse valide de rtgre.fr ou de www.rtgre.fr depuis cinq minutes. Les visiteurs sont touchés. Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

## 1. Confirmer depuis l'extérieur

```bash
curl -sI https://rtgre.fr/ | head -n 1
dig +short rtgre.fr A
```

Une réponse `HTTP/2 200` : la panne est entre le cluster et lui-même, les visiteurs ne sont pas touchés. Passer directement à l'étape 3.

## 2. Si la panne dure, revenir à GitHub Pages

GitHub Pages reste déployé chaque heure en secours. Si la cause n'est pas trouvée en un quart d'heure, y renvoyer les visiteurs, puis chercher sans pression : [basculer-rtgre-fr](basculer-rtgre-fr.md). Le retour prend quelques secondes, et cinq minutes au plus pour les visiteurs.

## 3. Trouver l'étage en panne

Une requête traverse le DNS, le load balancer, la passerelle, puis le serveur web.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl get nodes
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n gateway get pods,gateway,certificate
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre get pods,httproute
```

| Constat | Cause | Que faire |
| --- | --- | --- |
| `dig` ne renvoie pas l'adresse du load balancer | La zone DNS a changé. | Comparer avec [`terraform/dns`](../../terraform/dns) : `terraform plan` doit être vide. |
| Un nœud est `NotReady`, ou la session du Bastion ne s'ouvre pas | Le nœud est arrêté ou saturé. | Le redémarrer depuis la console d'Oracle. Voir [noeud-a-court-de-ressources](noeud-a-court-de-ressources.md). |
| Le pod `gateway-traefik` n'est pas prêt | La passerelle est en panne. | [diagnostiquer-un-pod](diagnostiquer-un-pod.md). |
| Le certificat `public` n'est pas `Ready`, ou `curl` refuse le certificat | Le certificat a expiré. | [suivre-les-certificats](suivre-les-certificats.md). |
| Le pod `rtgre-web` n'est pas prêt | Le serveur web est en panne, ou son volume est vide. | [suivre-la-generation-du-site](suivre-la-generation-du-site.md), section « Le site ne répond plus ». |
| Tout est prêt, et `curl` échoue quand même | Le load balancer ne joint plus le nœud. | Dans la console d'Oracle, lire l'état des backends du Network Load Balancer, puis les règles du NSG des nœuds. |

## 4. Après la panne

Si les visiteurs ont été renvoyés sur GitHub Pages, revenir au cluster par la même procédure. Ouvrir une issue « Incident », puis écrire le post-mortem dans `docs/postmortems/`.
