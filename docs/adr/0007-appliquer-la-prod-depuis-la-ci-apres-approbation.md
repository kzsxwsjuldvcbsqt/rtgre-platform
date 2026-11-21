# 0007. Appliquer la prod depuis la CI, après approbation

- Statut : accepté
- Date : 2026-11-21

## Contexte

Jusqu'ici, la prod est appliquée depuis un poste administrateur. Rien ne garantit alors que ce qui tourne correspond à `main`, et la revue d'une PR porte sur du code, pas sur ce que Terraform va réellement faire.

La CI sait déjà s'authentifier sans clé API ([ADR 0005](0005-authentifier-la-ci-par-federation-d-identite.md)).

## Options envisagées

### Apply automatique à chaque fusion

Le plus simple. Mais une fusion déclenche aussitôt des changements en prod, y compris une destruction qu'un plan de PR aurait affichée sans que personne ne la lise.

### Apply depuis le poste, plan en CI

Le plan est visible dans chaque PR, mais l'apply reste manuel et peut partir d'une branche qui n'est pas `main`.

### Plan relu puis apply approuvé dans la CI

Le plan de `main` est enregistré, puis appliqué tel quel par un job d'un environnement GitHub protégé qui attend une approbation.

## Décision

Plan relu puis apply approuvé :

- sur chaque PR qui touche la prod ou les modules, la CI publie le plan en commentaire, calculé avec l'identité en lecture seule et sans verrou ;
- sur `main`, le plan est enregistré en artefact. S'il contient des changements, le job `Apply (prod)` de l'environnement `production` l'applique tel quel ;
- l'environnement `production` n'accepte que la branche `main` et demande l'approbation du propriétaire du dépôt ;
- seuls les jobs de cet environnement peuvent emprunter l'identité d'apply. Elle gère le réseau, les instances et les volumes du compartiment, et n'écrit que dans le bucket du state.

## Conséquences

- Ce qui est approuvé est exactement ce qui est appliqué : Terraform refuse un plan enregistré si le state a changé depuis.
- Une PR ne peut rien modifier en prod, même en changeant le workflow : son jeton n'emprunte que l'identité de lecture.
- Chaque déploiement demande un clic d'approbation. C'est voulu pour une prod gérée seul.
- Le plan enregistré peut contenir des valeurs sensibles, par exemple les sorties du state du bootstrap lues par `terraform_remote_state`. Il est conservé un jour dans un dépôt privé.
- Le bootstrap reste appliqué depuis un poste administrateur : il gère l'IAM de la tenancy, que la CI ne doit pas pouvoir modifier.
- Une modification de la prod appliquée depuis un poste sans passer par `main` apparaîtra comme un écart au plan suivant de la CI.
