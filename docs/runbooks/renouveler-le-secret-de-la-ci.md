# Renouveler le secret de la CI

À utiliser si le secret `OCI_CLIENT_SECRET` a pu fuiter, ou lors d'une rotation planifiée.

Le secret seul ne donne accès à aucune API Oracle : il faut aussi un jeton OIDC émis par GitHub pour ce dépôt. La rotation reste nécessaire dès qu'une fuite est possible.

## Procédure

Depuis `terraform/bootstrap`, sur un poste administrateur :

1. Recréer l'application OAuth. Son identifiant et son secret changent, et la confiance est mise à jour dans le même apply :

   ```bash
   terraform apply -replace=oci_identity_domains_app.ci_token_exchange
   ```

2. Mettre à jour l'identifiant et le secret dans GitHub, sans que le secret n'apparaisse à l'écran :

   ```bash
   gh variable set OCI_CLIENT_ID --body "$(terraform output -raw ci_token_exchange_client_id)"
   terraform output -raw ci_token_exchange_client_secret | gh secret set OCI_CLIENT_SECRET
   ```

3. Relancer le workflow `Oracle access` et vérifier qu'il passe :

   ```bash
   gh workflow run oracle-access.yml --ref main
   ```

Entre les étapes 1 et 2, les jobs qui s'authentifient auprès d'Oracle échouent : l'ancien identifiant n'existe plus.
