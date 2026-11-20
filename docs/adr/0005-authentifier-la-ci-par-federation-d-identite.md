# 0005. Authentifier la CI par fédération d'identité

- Statut : accepté
- Date : 2026-11-20

## Contexte

GitHub Actions doit pouvoir lancer Terraform contre la tenancy : lire le state et planifier dès maintenant, appliquer plus tard. La façon la plus courante de le permettre, une clé API Oracle stockée dans les secrets du dépôt, donne un accès permanent à quiconque récupère ce secret, et n'expire jamais d'elle-même.

GitHub Actions délivre à chaque job un jeton OIDC signé, qui décrit précisément le dépôt, la branche ou l'événement à l'origine du job. Depuis juillet 2025, les domaines d'identité Oracle savent échanger un tel jeton contre un jeton Oracle de courte durée ([documentation](https://docs.oracle.com/en-us/iaas/Content/Identity/api-getstarted/json_web_token_exchange.htm)).

## Options envisagées

### Clé API dans les secrets GitHub

Simple et documentée partout. Mais la clé est permanente, liée à un utilisateur, et suffit à elle seule pour appeler toutes les API autorisées.

### Fédération avec un jeton UPST

Une confiance de propagation d'identité accepte les jetons de GitHub, vérifie leur claim `sub` et émet un jeton de session (UPST) au nom d'un utilisateur de service, sans mot de passe ni clé API. Le provider et le backend `oci` l'utilisent tous les deux avec `auth = "SecurityToken"`.

L'appel d'échange doit être authentifié par une application OAuth confidentielle : un secret reste donc stocké dans GitHub. Ce secret ne permet aucun appel aux API Oracle sans un jeton GitHub valide qui respecte la confiance.

### Fédération avec un jeton RPST

Une variante plus récente, sans utilisateur de service : les droits sont donnés par des conditions de politique sur les claims propagés. Elle exige le même secret OAuth. Surtout, le backend `oci` de Terraform 1.17 n'accepte pas la méthode `WorkloadIdentityFederation`, et aucun usage publié ne montre un RPST fédéré utilisé par ce backend.

### Runner auto-hébergé sur une instance Oracle

Seule option vraiment sans secret, grâce à l'instance principal. Mais elle consomme une partie des 2 OCPU gratuits, et un runner qui exécute le code des pull requests à l'intérieur de la tenancy pose plus de risques qu'il n'en retire.

## Décision

Fédération avec un jeton UPST, entièrement déclarée dans `terraform/bootstrap/ci_identity.tf` :

- l'utilisateur de service `rtgre-platform-ci-plan`, membre du groupe du même nom ;
- une politique qui donne à ce groupe la lecture seule sur le compartiment de la plateforme ;
- l'application OAuth `rtgre-platform-ci-token-exchange` ;
- une confiance qui n'accepte que les jetons dont le `sub` vaut `<préfixe>:pull_request` ou `<préfixe>:ref:refs/heads/main`. Le préfixe est le sujet immuable de GitHub, `repo:<propriétaire>@<id>/<dépôt>@<id>` : un dépôt supprimé puis recréé sous le même nom n'aurait pas les mêmes identifiants, et serait refusé.

L'échange est fait par une action composite du dépôt, `.github/actions/oci-login`, plutôt que par une action tierce.

## Conséquences

- Aucune clé API Oracle n'est stockée dans GitHub. Le seul secret, celui de l'application OAuth, est inutile sans un jeton GitHub de ce dépôt.
- Chaque job obtient un jeton qui expire de lui-même, lié à une paire de clés générée pour ce seul job.
- L'identité des pull requests est en lecture seule : les plans de PR tournent avec `-lock=false`, et une PR ne peut ni modifier l'infrastructure ni réécrire le state. Le workflow `Oracle access` le vérifie à chaque modification de cette configuration.
- Appliquer depuis la CI demandera une seconde identité, réservée à un environnement GitHub protégé (`sub` = `<préfixe>:environment:<nom>`), avec ses propres droits. Elle viendra avec la première configuration appliquée par la CI.
- Le secret de l'application est lisible dans le state Terraform. Le bucket du state est privé, mais quiconque peut lire le state peut lire ce secret. La rotation est décrite dans le runbook [Renouveler le secret de la CI](../runbooks/renouveler-le-secret-de-la-ci.md).
- Le domaine d'identité est de type gratuit, limité à deux applications non Oracle. Cette application en occupe une.
- Le bootstrap lui-même reste appliqué depuis un poste administrateur : il gère l'IAM de la tenancy, et la CI n'a volontairement aucun droit pour le faire.
