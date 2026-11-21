# Politique de sécurité

## Signaler une vulnérabilité

N'ouvrez pas d'issue publique. Utilisez le [signalement privé de GitHub](https://github.com/kzsxwsjuldvcbsqt/rtgre-platform/security/advisories/new) (onglet Security, « Report a vulnerability »).

Décrivez la ressource ou le fichier concerné, les étapes pour reproduire le problème et son effet. Ne joignez jamais de secret, de clé ni d'extrait de state Terraform. Le signalement reste privé jusqu'à la publication du correctif.

## Périmètre

- le code d'infrastructure de ce dépôt : Terraform, Ansible, manifestes Kubernetes et scripts ;
- ses workflows GitHub Actions et la fédération d'identité qui leur donne accès à Oracle Cloud ;
- les machines et le cluster qu'il décrit, qui servent [rtgre.fr](https://rtgre.fr).

Le site lui-même relève de [rtgre](https://github.com/kzsxwsjuldvcbsqt/rtgre/security/policy).

## Secrets

Aucun secret n'est versionné. Les identifiants d'Oracle Cloud restent sur le poste (`~/.oci`) ou dans les secrets GitHub. La CI obtient des jetons de courte durée par fédération d'identité ([ADR 0005](docs/adr/0005-authentifier-la-ci-par-federation-d-identite.md)). Gitleaks analyse chaque commit et tout l'historique, et la protection au push de GitHub bloque les secrets connus.
