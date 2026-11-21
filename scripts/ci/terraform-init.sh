#!/usr/bin/env bash
# Initialise une configuration Terraform en CI : le backend oci est décrit par les variables
# du dépôt, et le namespace Object Storage est lu auprès d'Oracle plutôt que recopié.
#
# Variables attendues : TF_VAR_state_bucket, TF_VAR_region. Le profil DEFAULT de
# ~/.oci/config doit avoir été écrit par l'action oci-login.
set -euo pipefail

namespace=$(oci os ns get --auth security_token --query data --raw-output)
echo "TF_VAR_objectstorage_namespace=$namespace" >> "$GITHUB_ENV"

terraform init -no-color \
  -backend-config="bucket=$TF_VAR_state_bucket" \
  -backend-config="namespace=$namespace" \
  -backend-config="region=$TF_VAR_region" \
  -backend-config="auth=SecurityToken" \
  -backend-config="config_file_profile=DEFAULT"
