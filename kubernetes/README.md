# Kubernetes

Ce qui tourne dans le cluster est décrit ici et déployé par Argo CD ([ADR 0010](../docs/adr/0010-deployer-en-gitops-avec-argo-cd.md)). Rien ne s'applique à la main : une modification passe par une pull request, et Argo CD l'applique dans les minutes qui suivent sa fusion.

| Dossier | Rôle |
| --- | --- |
| [`apps`](apps) | Application racine : le projet `platform`, et une application Argo CD par entrée de ses valeurs, elle-même comprise |
| [`argocd`](argocd) | Argo CD : le chart officiel `argo-cd`, figé dans `Chart.lock`, et les valeurs de la plateforme |

Le réseau des pods, Cilium, n'est pas ici : Argo CD en a besoin pour démarrer, c'est donc Ansible qui l'installe ([rôle `cilium`](../ansible/roles/cilium)).

## Ajouter une application

1. Créer son chart dans `kubernetes/<nom>/`. Pour un chart tiers, le déclarer en dépendance dans `Chart.yaml`, de préférence depuis un registre OCI, et écrire ses valeurs sous la clé du même nom. Lancer `helm dependency update kubernetes/<nom>` pour créer `Chart.lock`.
2. Ajouter une entrée `<nom>` sous `applications` dans [`apps/values.yaml`](apps/values.yaml), avec son espace de noms.
3. Vérifier, puis ouvrir la pull request :

```bash
mise run kubernetes-validate
```

Le dépôt suivi et sa branche ne sont écrits qu'à un endroit : `repository` dans `apps/values.yaml`.

## Amorçage

Argo CD ne peut pas s'installer lui-même la première fois. Le rôle Ansible [`argocd`](../ansible/roles/argocd) rend ces deux charts et les applique une fois, puis Argo CD prend le relais, y compris pour ses propres mises à jour.
