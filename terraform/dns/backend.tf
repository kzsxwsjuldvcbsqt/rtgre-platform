terraform {
  # Le bucket, le namespace, la région et l'authentification viennent de backend.hcl :
  #   terraform init -backend-config=backend.hcl
  backend "oci" {
    key = "dns/terraform.tfstate"
  }
}
