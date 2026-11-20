# 0001. Consigner les décisions d'architecture

- Statut : accepté
- Date : 2026-11-20

## Contexte

Une infrastructure accumule des choix dont la raison se perd vite : pourquoi ce fournisseur, pourquoi cette taille de machine, pourquoi cet outil plutôt qu'un autre. Quelques mois plus tard, le code dit ce qui a été fait mais plus pourquoi. On hésite alors à changer une décision dont on ne connaît plus les contraintes, ou on la change sans voir ce qu'elle protégeait.

## Options envisagées

### Ne rien écrire

Aucun effort, mais les raisons ne vivent que dans la mémoire de la personne qui a décidé.

### Une page unique dans le README

Simple, mais elle grossit sans structure, et rien ne montre qu'une décision a été remplacée par une autre.

### Des Architecture Decision Records

Un fichier court par décision, numéroté, daté et versionné avec le code. Une décision n'est jamais modifiée après son acceptation : on en écrit une nouvelle qui la remplace.

## Décision

Chaque décision structurante est consignée dans `docs/adr/` sous la forme d'un ADR qui reprend `template.md`. Une décision est structurante quand la changer demanderait de modifier plusieurs composants ou de recréer des ressources.

## Conséquences

- La raison d'un choix se retrouve dans le dépôt, à côté du code qu'elle explique.
- Une pull request qui change une décision structurante doit ajouter l'ADR qui la remplace.
- Les ADR acceptés ne sont plus modifiés, sauf leur statut quand un nouvel ADR les remplace.
