terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}
