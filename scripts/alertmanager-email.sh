#!/usr/bin/env bash
# Donne à Alertmanager de quoi envoyer les alertes par courrier, puis envoie une alerte d'essai.
#
#   scripts/bastion-ssh-config.sh
#   scripts/alertmanager-email.sh          # crée ou remplace le Secret, puis essaie
#   scripts/alertmanager-email.sh --test   # envoie seulement l'alerte d'essai
#
# L'identifiant et le mot de passe SMTP sont lus dans le state du bootstrap, et l'adresse du
# destinataire dans un fichier du poste. Aucun n'est passé en argument d'une commande, écrit sur
# un nœud ou affiché.
#
# Variables facultatives :
#   RTGRE_ALERT_RECIPIENT_FILE   fichier de l'adresse (défaut : ~/.config/rtgre-platform/alert-recipient)
#   RTGRE_SSH_CONFIG             configuration SSH (défaut : ansible/.ssh/bastion.conf)
set -euo pipefail

mode=${1:-}
repo=$(git rev-parse --show-toplevel)
config=${RTGRE_SSH_CONFIG:-$repo/ansible/.ssh/bastion.conf}
recipient_file=${RTGRE_ALERT_RECIPIENT_FILE:-$HOME/.config/rtgre-platform/alert-recipient}
values=$repo/kubernetes/monitoring/values.yaml
bootstrap=$repo/terraform/bootstrap

namespace=$(awk '/^  monitoring:/ { found = 1; next } found && $1 == "namespace:" { print $2; exit }' \
  "$repo/kubernetes/apps/values.yaml")
secret=$(sed -n 's/^    secretName: &emailSecret //p' "$values")
runbooks=$(sed -n 's/^  runbookBaseUrl: //p' "$values")
: "${namespace:?espace de noms de monitoring introuvable dans kubernetes/apps/values.yaml}"
: "${secret:?alerting.email.secretName est introuvable dans $values}"
: "${runbooks:?alerting.runbookBaseUrl est introuvable dans $values}"

# Premier hôte de la configuration du Bastion dont le nom commence par cp-.
control_plane=$(awk '$1 == "Host" { for (i = 2; i <= NF; i++) if ($i ~ /^cp-/) { print $i; exit } }' "$config")

# ssh recolle ses arguments avant de les passer au shell du nœud : chacun est protégé d'abord.
remote_kubectl() {
  local command
  command=$(printf '%q ' kubectl --namespace "$namespace" "$@")
  ssh -F "$config" -o BatchMode=yes -o LogLevel=ERROR "$control_plane" "$command"
}

alertmanager_pod() {
  remote_kubectl get pods --selector app.kubernetes.io/name=alertmanager --output name | head -n 1
}

# Tentatives d'envoi par courrier, réussies ou non (« requests_total ») ou en échec
# (« requests_failed_total »), lues dans les métriques d'Alertmanager.
requests() {
  remote_kubectl exec "$pod" --container alertmanager -- wget -q -O - http://127.0.0.1:9093/metrics |
    awk -v metric="alertmanager_notification_$1{integration=\"email\"}" '$1 == metric { print $2; found = 1 } END { if (!found) print 0 }'
}

if [ "$mode" != "--test" ]; then
  if [ ! -s "$recipient_file" ]; then
    echo "Adresse du destinataire introuvable : $recipient_file (docs/runbooks/recevoir-les-alertes.md)." >&2
    exit 1
  fi
  recipient=$(tr -d '[:space:]' < "$recipient_file")
  if ! [[ $recipient =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
    echo "$recipient_file ne contient pas une adresse de courrier." >&2
    exit 1
  fi

  username=$(terraform -chdir="$bootstrap" output -raw alert_smtp_username)
  password=$(terraform -chdir="$bootstrap" output -raw alert_smtp_password)

  # Le manifeste est écrit par Python, qui échappe le mot de passe, et passe d'un tube à
  # l'autre. Appliqué côté serveur : kubectl ne recopie pas le Secret dans une annotation.
  printf '%s\n%s\n%s\n%s\n' "$secret" "$username" "$password" "$recipient" |
    python3 -c '
import json, sys
name, username, password, recipient = sys.stdin.read().split("\n")[:4]
print(json.dumps({
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": name},
    "stringData": {"smtp-username": username, "smtp-password": password, "recipient": recipient},
}))' |
    remote_kubectl apply --server-side --field-manager rtgre-platform --filename -
  unset password

  # Les valeurs sont lues au démarrage du pod : il est remplacé.
  pod=$(alertmanager_pod)
  if [ -n "$pod" ]; then
    remote_kubectl delete "$pod" --wait=true
  fi
fi

echo "Attente d'Alertmanager…"
remote_kubectl rollout status statefulset/alertmanager-monitoring-alertmanager --timeout 180s
pod=$(alertmanager_pod)
: "${pod:?Alertmanager ne tourne pas dans $namespace}"

sent=$(requests requests_total)
failed=$(requests requests_failed_total)

remote_kubectl exec "$pod" --container alertmanager -- amtool alert add EssaiDesAlertes severity=info \
  --annotation "summary=\"Alerte d'essai envoyée par scripts/alertmanager-email.sh\"" \
  --annotation "description=\"Rien à faire : la chaîne d'alerte fonctionne.\"" \
  --annotation "runbook_url=\"$runbooks/recevoir-les-alertes.md\"" \
  --alertmanager.url http://127.0.0.1:9093

# Alertmanager attend trente secondes avant d'envoyer, pour regrouper.
echo "Alerte d'essai créée. Attente de son envoi…"
for _ in $(seq 1 18); do
  sleep 5
  if [ "$(requests requests_total)" -gt "$sent" ]; then
    break
  fi
done

if [ "$(requests requests_failed_total)" -gt "$failed" ]; then
  echo "L'envoi a échoué : voir « Aucun message n'arrive » dans docs/runbooks/recevoir-les-alertes.md." >&2
  exit 1
fi
if [ "$(requests requests_total)" -le "$sent" ]; then
  echo "Aucun envoi en une minute et demie : lire le journal d'Alertmanager." >&2
  exit 1
fi
echo "Courrier remis au serveur d'envoi. Le message « Résolu » suivra dans cinq minutes."
