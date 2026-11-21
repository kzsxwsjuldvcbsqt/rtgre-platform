# Kubernetes

Ce qui tourne dans le cluster est décrit ici et déployé par Argo CD ([ADR 0010](../docs/adr/0010-deployer-en-gitops-avec-argo-cd.md)). Rien ne s'applique à la main : une modification passe par une pull request, et Argo CD l'applique dans les minutes qui suivent sa fusion.

| Dossier | Rôle |
| --- | --- |
| [`apps`](apps) | Application racine : le projet `platform`, et une application Argo CD par entrée de ses valeurs, elle-même comprise |
| [`argocd`](argocd) | Argo CD : le chart officiel `argo-cd`, figé dans `Chart.lock`, et les valeurs de la plateforme |
| [`cert-manager`](cert-manager) | Certificats : cert-manager et ses émetteurs Let's Encrypt |
| [`gateway`](gateway) | Passerelle du cluster : Traefik en contrôleur Gateway API, et son certificat |
| [`rtgre`](rtgre) | Le site rtgre.fr : génération horaire depuis ADE, et serveur web |
| [`storage`](storage) | Volumes persistants locaux, déclarés un par un |

[`signed-images.txt`](signed-images.txt) liste les images qui doivent être signées, et par qui.

Le réseau des pods, Cilium, n'est pas ici : Argo CD en a besoin pour démarrer, c'est donc Ansible qui l'installe ([rôle `cilium`](../ansible/roles/cilium)).

## Ajouter une application

1. Créer son chart dans `kubernetes/<nom>/`. Pour un chart tiers, le déclarer en dépendance dans `Chart.yaml`, de préférence depuis un registre OCI, et écrire ses valeurs sous la clé du même nom. Lancer `helm dependency update kubernetes/<nom>` pour créer `Chart.lock`.
2. Ajouter une entrée `<nom>` sous `applications` dans [`apps/values.yaml`](apps/values.yaml), avec son espace de noms.
3. Vérifier, puis ouvrir la pull request :

```bash
mise run kubernetes-validate
```

Cette commande rend chaque chart pour la version de Kubernetes du cluster, valide les objets obtenus, puis vérifie la signature des images qui doivent en porter une.

Une image se référence par son empreinte, dans des valeurs `repository` et `tag` (`tag: 1.2.3@sha256:…`) : Renovate la tient alors à jour.

Le dépôt suivi et sa branche ne sont écrits qu'à un endroit : `repository` dans `apps/values.yaml`.

Une application peut aussi venir d'un autre dépôt, avec une entrée `source` : c'est le cas des CRD de Gateway API, lues dans leur dépôt officiel à un commit épinglé. Le projet `platform` n'accepte que les dépôts ainsi déclarés.

## Essayer une branche avant de la fusionner

L'application racine suit `main` : une application nouvelle n'existe donc qu'après la fusion. Pour la voir tourner avant, depuis la branche, une fois poussée :

```bash
scripts/argocd-try-branch.sh feat/ma-branche
```

Le script suspend la synchronisation de l'application racine, puis pointe les projets et les applications sur la branche. Après la fusion, depuis `main` à jour, la même commande sans argument remet tout sur la révision du dépôt :

```bash
scripts/argocd-try-branch.sh
```

## Amorçage

Argo CD ne peut pas s'installer lui-même la première fois. Le rôle Ansible [`argocd`](../ansible/roles/argocd) rend ces deux charts et les applique une fois, puis Argo CD prend le relais, y compris pour ses propres mises à jour.
