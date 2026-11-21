#!/usr/bin/env bash
# Publie le plan Terraform en commentaire de la pull request, en remplaçant le précédent.
#
# Variables attendues : GH_TOKEN, PR_NUMBER, CHANGES (true ou false), et plan.log dans le
# dossier courant.
set -euo pipefail

: "${PR_NUMBER:?PR_NUMBER doit être défini.}"
: "${CHANGES:?CHANGES doit valoir true ou false.}"

# Un commentaire GitHub est limité à 65 536 caractères : le plan est tronqué au-delà.
max_plan_chars=60000
plan=$(sed -n '/Terraform will perform\|No changes\|Changes to Outputs/,$p' plan.log)
if [ ${#plan} -gt "$max_plan_chars" ]; then
  plan="${plan:0:$max_plan_chars}
… plan tronqué, voir les journaux du job."
fi

if [ "$CHANGES" = "true" ]; then
  summary=$(grep -E '^Plan:' plan.log || echo "Changements des sorties uniquement.")
else
  summary="Aucun changement."
fi

body_file=$(mktemp)
{
  echo "### Plan Terraform : prod"
  echo
  echo "**$summary**"
  echo
  echo "<details><summary>Détail du plan</summary>"
  echo
  echo '```'
  echo "$plan"
  echo '```'
  echo
  echo "</details>"
  echo
  echo "Commit ${GITHUB_SHA:0:7}, [run $GITHUB_RUN_ID]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)."
} > "$body_file"

gh pr comment "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" --edit-last --create-if-none --body-file "$body_file"
