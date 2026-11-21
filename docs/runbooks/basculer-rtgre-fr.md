# Basculer rtgre.fr

rtgre.fr est servi soit par le cluster, soit par GitHub Pages, qui reste déployé chaque heure en secours. Une seule valeur en décide : `site_served_by`, dans [`terraform/dns/zone.auto.tfvars`](../../terraform/dns/zone.auto.tfvars).

| Valeur | Sommet de la zone | `www` |
| --- | --- | --- |
| `cluster` | Adresse du load balancer, sans IPv6, durée de vie de 5 minutes | CNAME vers `rtgre.fr.` |
| `github-pages` | Quatre adresses IPv4 et quatre IPv6 de GitHub, durée de vie d'une heure | CNAME vers GitHub |

Les serveurs de noms, les MX et le SPF ne dépendent pas de cette valeur.

## Revenir à GitHub Pages en urgence

À faire quand le cluster ne sert plus le site et que la panne ne se corrige pas vite. Depuis `terraform/dns`, avec les clés d'OVH dans `~/.ovh.conf` :

```bash
terraform apply -var site_served_by=github-pages
```

Le plan annonce 2 modifications et 7 créations. Les visiteurs reviennent sur GitHub Pages au fil de l'expiration de leur cache DNS, en 5 minutes au plus.

Vérifier :

```bash
dig +short @ns111.ovh.net rtgre.fr A
curl -sI https://rtgre.fr/ | grep -i '^server'
```

Les quatre adresses `185.199.108.153` à `185.199.111.153` et `server: GitHub.com` confirment le retour. Ouvrir ensuite une pull request qui passe `site_served_by` à `github-pages`, pour que le dépôt dise la vérité : sans elle, le prochain `terraform apply` rebasculerait vers le cluster.

## Basculer vers le cluster

1. Vérifier que le cluster sert bien le site, sous son nom de test :

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://test.rtgre.fr/
```

2. Passer `site_served_by` à `cluster` par une pull request, puis, depuis `terraform/dns` sur `main` :

```bash
terraform apply
```

3. Si le certificat de la passerelle ne couvre pas encore `rtgre.fr` et `www.rtgre.fr`, les ajouter à `certificate.dnsNames` dans `kubernetes/gateway/values.yaml` **juste après** l'étape 2 : Let's Encrypt ne valide un nom que s'il désigne déjà le cluster ([ADR 0013](../adr/0013-certificats-par-cert-manager-et-lets-encrypt.md)). Le certificat arrive en une minute environ. Lors d'un retour vers le cluster, il est déjà là : rien à faire.

4. Vérifier :

```bash
dig +short @ns111.ovh.net rtgre.fr A
curl -sI https://rtgre.fr/ | grep -iE '^HTTP|^server|strict'
curl -sI https://www.rtgre.fr/x | grep -iE '^HTTP|^location'
dig +short @ns111.ovh.net rtgre.fr MX
```

Une seule adresse, celle du load balancer ; `server: nginx` ; `www` qui renvoie vers `https://rtgre.fr/x` ; les trois MX inchangés.

## Ce qu'il faut savoir

- **Pendant la première bascule**, entre le changement du DNS et l'arrivée du certificat, un visiteur qui résout déjà la nouvelle adresse voit une erreur de certificat. Ceux dont le cache DNS désigne encore GitHub Pages, la grande majorité pendant une heure, ne voient rien.
- **Le secours s'use** : le certificat que GitHub Pages détient pour rtgre.fr ne se renouvelle que si le nom désigne GitHub. Après son expiration, un retour vers GitHub Pages afficherait une erreur de certificat le temps que GitHub en obtienne un nouveau, de quelques minutes à une heure. Sa date se lit ainsi, tant que le site est sur GitHub Pages, ou dans les réglages Pages du dépôt rtgre :

```bash
gh api repos/kzsxwsjuldvcbsqt/rtgre/pages --jq .https_certificate.expires_at
```

- **Le site n'a pas d'IPv6 sur le cluster.** Un visiteur en IPv6 seul, sans passerelle vers IPv4, ne peut pas l'atteindre. C'est rare, et sans effet sur les autres.
- **Deux générations par heure interrogent ADE** tant que le secours tourne : celle du cluster et celle de GitHub Pages.
