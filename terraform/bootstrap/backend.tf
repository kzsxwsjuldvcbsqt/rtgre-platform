terraform {
  # Le bucket, le namespace, la région et le profil viennent de backend.hcl :
  #   terraform init -backend-config=backend.hcl
  backend "oci" {
    key = "bootstrap/terraform.tfstate"
  }
}
