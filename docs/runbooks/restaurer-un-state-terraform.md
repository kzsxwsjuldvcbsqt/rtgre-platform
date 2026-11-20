# Restaurer un state Terraform

À utiliser quand un state du bucket `rtgre-platform-tfstate` est corrompu, supprimé par erreur, ou quand un verrou reste bloqué après une exécution interrompue.

Les commandes se lancent depuis le dossier de la configuration concernée, par exemple `terraform/bootstrap`, après un `terraform init -backend-config=backend.hcl`.

## Verrou bloqué

Symptôme : `Error acquiring the state lock` alors qu'aucune autre exécution n'est en cours, par exemple après un Ctrl+C ou une coupure réseau.

1. Vérifier qu'aucune autre exécution n'est réellement en cours : poste, CI.
2. Relever l'identifiant `ID:` affiché dans le message d'erreur.
3. Libérer le verrou :

   ```bash
   terraform force-unlock <ID>
   ```

## Revenir à une version antérieure du state

1. Lister les versions de l'objet :

   ```bash
   oci os object list-object-versions -bn rtgre-platform-tfstate \
     --prefix bootstrap/terraform.tfstate \
     --query 'data[].{version:"version-id",modifie:"time-modified",taille:size}' \
     --output table
   ```

2. Télécharger la version voulue :

   ```bash
   oci os object get -bn rtgre-platform-tfstate \
     --name bootstrap/terraform.tfstate \
     --version-id <version> --file restore.tfstate
   ```

3. Vérifier son contenu avant de le pousser :

   ```bash
   terraform show restore.tfstate
   ```

4. Le pousser comme state courant. Terraform refuse un state plus ancien que l'actuel sans `-force` :

   ```bash
   terraform state push -force restore.tfstate
   ```

5. Contrôler avec `terraform plan`. Les écarts affichés sont les changements faits depuis cette version : les réappliquer ou les importer.

6. Supprimer `restore.tfstate`, qui contient les identifiants de toutes les ressources.
