# Contribuer à rtgre-platform

Ce guide décrit la façon de travailler sur le dépôt. Les mêmes règles s'appliquent à [rtgre](https://github.com/kzsxwsjuldvcbsqt/rtgre), le site déployé par cette plateforme.

## Préparer le poste

Les versions des outils sont fixées dans `mise.toml`. La CI utilise les mêmes.

```bash
mise install
mise run ansible-deps
pre-commit install
```

Les fichiers propres au poste ne sont jamais versionnés : `backend.hcl` et `terraform.tfvars` de chaque stack, la configuration `~/.oci` et `ansible/.ssh/`. Le [README](README.md) décrit leur contenu.

## Façon de travailler

1. Chaque travail part d'une issue, ouverte avec le modèle « Tâche » ou « Incident », rattachée au jalon de sa phase.
2. Une branche par issue, créée depuis `main` et nommée `type/sujet`, par exemple `feat/noeuds` ou `ci/renovate`.
3. Une pull request qui remplit le modèle et ferme l'issue avec `Closes #n`. Le workflow Terraform y commente le plan de chaque stack.
4. La fusion se fait par commit de merge, une fois la CI verte. La branche est supprimée ensuite.
5. L'environnement de production n'est modifié que par le job « Apply (prod) ». Ce job applique le plan enregistré, après approbation dans l'environnement GitHub `production` ([ADR 0007](docs/adr/0007-appliquer-la-prod-depuis-la-ci-apres-approbation.md)).

`main` est protégée : pas de poussée directe, pas de réécriture, commits signés et contrôles verts obligatoires.

## Messages de commit

Les messages suivent [Conventional Commits](https://www.conventionalcommits.org/fr/), en français :

```text
type(portée): description au présent, sans majuscule ni point final

Corps facultatif : le pourquoi du changement, pas le comment.

Closes #12
```

| Type | Usage |
| --- | --- |
| `feat` | ressource, rôle ou fonction nouvelle |
| `fix` | correction d'une erreur |
| `perf` | gain de temps ou de ressources |
| `refactor` | réorganisation sans changement de l'infrastructure |
| `test` | tests seuls (Molecule, validations) |
| `docs` | documentation, ADR, runbooks |
| `build` | outils, `mise.toml` |
| `ci` | workflows GitHub Actions |
| `chore` | maintenance, mises à jour de dépendances |
| `revert` | annulation d'un commit |

La portée désigne la partie touchée : `bootstrap`, `prod`, `network`, `compute`, `bastion`, `ansible`, `hardening`, `kubernetes-node`, `kubeadm`, `cilium`, `scripts`, `adr`, `deps`… La première ligne fait au plus 80 caractères. Le hook `conventional-pre-commit` vérifie le format en local, et le workflow Quality vérifie chaque commit d'une pull request.

## Signature des commits

Tous les commits sont signés. Avec une clé SSH déjà déclarée sur GitHub comme clé de signature :

```bash
git config gpg.format ssh
git config user.signingkey ~/.ssh/<clé>.pub
git config commit.gpgsign true
git config tag.gpgSign true
```

## Décisions et procédures

- Une décision structurante s'accompagne d'un ADR dans `docs/adr/`, rédigé à partir de [template.md](docs/adr/template.md).
- Une opération à refaire, ou à mener en cas d'incident, est décrite dans un runbook de `docs/runbooks/`.
- Aucune valeur propre à l'environnement n'est écrite en dur : elle passe par une variable, un fichier `*.auto.tfvars` versionné ou les `group_vars` d'Ansible.

## Sécurité

Une vulnérabilité se signale en privé, jamais dans une issue publique : voir [SECURITY.md](SECURITY.md).
