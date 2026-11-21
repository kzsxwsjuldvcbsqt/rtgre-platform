# Renouveler la clé de déploiement d'Argo CD

Argo CD lit le dépôt en SSH avec une clé de déploiement en lecture seule ([ADR 0010](../adr/0010-deployer-en-gitops-avec-argo-cd.md)). Sa partie privée n'existe que dans le Secret `argocd-repo-platform` du cluster. Cette procédure la remplace : une fois par an, ou tout de suite si le Secret a pu être lu par un tiers.

## Prérequis

- Les sessions du Bastion ouvertes ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).
- `gh` authentifié avec un compte qui administre le dépôt : `gh auth status`.

## Renouveler

1. Supprimer le Secret. Argo CD ne peut plus lire le dépôt, mais ce qui tourne continue de tourner.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd delete secret argocd-repo-platform
```

2. Relancer le playbook, depuis `ansible/`. Le rôle `argocd` constate que le Secret manque : il génère une nouvelle paire, retire du dépôt l'ancienne clé du même titre, enregistre la nouvelle et recrée le Secret.

```bash
ansible-playbook playbooks/site.yml
```

## Vérifier

```bash
gh repo deploy-key list
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get applications
```

Le dépôt ne doit porter qu'une clé `argocd-rtgre-platform`, en lecture seule, créée à l'instant. Les applications doivent rester `Synced`. Pour forcer une lecture du dépôt sans attendre :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd annotate application root argocd.argoproj.io/refresh=hard --overwrite
```

## En cas d'échec

- **`gh` refuse d'ajouter la clé** : le compte n'administre pas le dépôt, ou son jeton n'a pas le droit `repo`. Le Secret n'est pas recréé : corriger, puis relancer le playbook.
- **Les applications passent en `ComparisonError` avec « authentication required »** : la clé du Secret et celle du dépôt ne correspondent plus. Reprendre à l'étape 1.
