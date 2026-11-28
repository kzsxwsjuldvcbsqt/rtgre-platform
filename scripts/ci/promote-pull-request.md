## Objet

Mettre en ligne la dernière image publiée par son dépôt : $SUMMARY.

## Changements

- L'empreinte de l'image passe à celle que porte aujourd'hui son tag dans le registre.

## Vérification

- `scripts/ci/promote-signed-images.sh` a vérifié la signature cosign de cette empreinte, avec l'identité attendue (`kubernetes/kyverno/files/signed-images.txt`).
- Les workflows `$GATE_WORKFLOWS` doivent réussir sur cette pull request avant sa fusion.

## Points d'attention

- [x] Aucune valeur propre à l'environnement n'est écrite en dur.
- [x] Une décision structurante est accompagnée de son ADR.
- [x] La documentation (README, runbooks) est à jour.
- [x] Proposée et fusionnée sans intervention par le workflow `Promote` ([exécution]($RUN_URL), ADR 0028).
