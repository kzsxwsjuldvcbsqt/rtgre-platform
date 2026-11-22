# DNS

Zone `rtgre.fr`, hébergée chez OVH. Tous ses enregistrements sont décrits dans [`zone.auto.tfvars`](zone.auto.tfvars) : rien ne se modifie dans l'espace client.

| Groupe | Contenu | Particularité |
| --- | --- | --- |
| `protected_records` | Serveurs de noms, MX, SPF | Terraform refuse de les supprimer (`prevent_destroy`) |
| `site_served_by` | Le sommet de la zone et `www` | Une seule valeur, `github-pages` ou `cluster`, calcule leurs enregistrements |
| `records` | Le reste, écrit tel quel | |
| `cluster_subdomains` | Noms qui désignent le cluster | Leur adresse est lue dans le state de la prod, pas recopiée |
| Courrier des alertes | SPF et clé DKIM du sous-domaine d'envoi | Lus dans le state du bootstrap, qui crée le domaine d'envoi ([ADR 0021](../../docs/adr/0021-envoyer-les-alertes-par-courrier.md)) |

## Appliquée depuis le poste

Comme le [socle](../bootstrap), cette configuration ne passe pas par la CI : les clés d'API d'OVH ne quittent pas le poste. Son state est dans le même bucket que les autres, sous la clé `dns/terraform.tfstate`.

```bash
cd terraform/dns
terraform init -backend-config=backend.hcl
terraform plan
```

`backend.hcl` et `terraform.tfvars` se copient depuis leurs fichiers `.example`. Un changement suit le cycle habituel : pull request, relecture du plan, fusion, puis `terraform apply` depuis `main`.

## Clés d'API d'OVH

Le provider lit `~/.ovh.conf`, en lecture pour son seul propriétaire (`chmod 600`) :

```ini
[default]
endpoint=ovh-eu

[ovh-eu]
application_key=…
application_secret=…
consumer_key=…
```

Le jeton se crée sur la [page de création d'OVH](https://www.ovh.com/auth/api/createToken), avec ces seuls droits. Il ne peut rien faire hors de la zone :

| Méthode | Chemin |
| --- | --- |
| GET | `/domain/zone/rtgre.fr` |
| GET, POST, PUT, DELETE | `/domain/zone/rtgre.fr/*` |
| GET | `/auth/details` |

Pour le révoquer : espace client d'OVH, « Mon compte », « Mes clés d'API ». Le remplacer consiste à en créer un nouveau et à mettre à jour `~/.ovh.conf`.

## Choix notables

- **Une durée de vie de 0** désigne celle de la zone, 3 600 secondes. C'est ce que portent les enregistrements créés depuis l'espace client : la garder évite de les modifier à l'import.
- **Les noms du cluster ont une durée de vie courte** (`cluster_ttl`) : l'adresse du load balancer est éphémère. S'il est recréé, un `terraform apply` ici fait suivre le DNS.
- **Le SPF a son propre type chez OVH**, qui le publie en TXT.
- **Les alertes partent d'un sous-domaine**, qui a son SPF et sa clé DKIM : ceux du domaine principal, protégés, ne changent pas.
- **Ne pas utiliser « Modifier en mode textuel »** dans l'espace client : OVH change alors l'identifiant de chaque enregistrement, et Terraform ne les retrouve plus.
- **Le site se bascule avec une seule valeur**, `site_served_by` : vers le cluster, le sommet de la zone prend l'adresse du load balancer et `www` le suit ; vers GitHub Pages, ils reprennent les adresses de GitHub. La procédure, retour arrière compris, est dans le runbook [basculer-rtgre-fr](../../docs/runbooks/basculer-rtgre-fr.md).
- **Le cluster n'a pas d'IPv6** : servi par lui, le site n'a pas d'enregistrement AAAA.

## Reprendre un enregistrement créé à la main

Un bloc `import`, dans un fichier temporaire, le rattache sans le modifier. L'identifiant se lit par l'API (`GET /domain/zone/rtgre.fr/record`) :

```hcl
import {
  to = ovh_domain_zone_record.this["ftp"]
  id = "<identifiant>.rtgre.fr"
}
```

Le plan doit alors annoncer un import et aucune modification. Les seize enregistrements d'origine ont été repris ainsi.
