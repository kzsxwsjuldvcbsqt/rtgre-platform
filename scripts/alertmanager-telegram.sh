#!/usr/bin/env bash
# Donne à Alertmanager le bot Telegram qui envoie les alertes, puis envoie une alerte d'essai.
#
#   scripts/bastion-ssh-config.sh
#   scripts/alertmanager-telegram.sh          # crée ou remplace le Secret, puis essaie
#   scripts/alertmanager-telegram.sh --test   # envoie seulement l'alerte d'essai
#
# Le jeton du bot est lu dans un fichier du poste. Il n'est ni passé en argument d'une commande,
# ni écrit sur un nœud, ni affiché. La discussion qui recevra les alertes est celle du dernier
# message que le bot a reçu : lui écrire d'abord.
#
# Variables facultatives :
#   RTGRE_TELEGRAM_TOKEN_FILE   fichier du jeton (défaut : ~/.config/rtgre-platform/telegram-bot-token)
#   RTGRE_TELEGRAM_CHAT_ID      discussion, pour ne pas la déduire du dernier message
#   RTGRE_SSH_CONFIG            configuration SSH (défaut : ansible/.ssh/bastion.conf)
set -euo pipefail

mode=${1:-}
repo=$(git rev-parse --show-toplevel)
config=${RTGRE_SSH_CONFIG:-$repo/ansible/.ssh/bastion.conf}
token_file=${RTGRE_TELEGRAM_TOKEN_FILE:-$HOME/.config/rtgre-platform/telegram-bot-token}
values=$repo/kubernetes/monitoring/values.yaml

namespace=$(awk '/^  monitoring:/ { found = 1; next } found && $1 == "namespace:" { print $2; exit }' \
  "$repo/kubernetes/apps/values.yaml")
secret=$(sed -n 's/^    secretName: &telegramSecret //p' "$values")
host=$(awk '/^  telegram:/ { found = 1; next } found && $1 == "host:" { print $2; exit }' "$values")
runbooks=$(sed -n 's/^  runbookBaseUrl: //p' "$values")
: "${namespace:?espace de noms de monitoring introuvable dans kubernetes/apps/values.yaml}"
: "${secret:?alerting.telegram.secretName est introuvable dans $values}"
: "${host:?alerting.telegram.host est introuvable dans $values}"
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

# L'adresse d'appel contient le jeton : curl la lit sur son entrée, pas dans ses arguments.
telegram() {
  local method=$1
  shift
  printf 'url = "https://%s/bot%s/%s"\n' "$host" "$token" "$method" |
    curl --config - --fail --silent --show-error --max-time 20 "$@"
}

if [ "$mode" != "--test" ]; then
  if [ ! -f "$token_file" ]; then
    echo "Jeton introuvable : $token_file (docs/runbooks/recevoir-les-alertes.md)." >&2
    exit 1
  fi
  if [ -n "$(find "$token_file" -perm /077)" ]; then
    echo "$token_file est lisible par d'autres comptes : chmod 600 $token_file" >&2
    exit 1
  fi
  token=$(tr -d '[:space:]' < "$token_file")
  if ! [[ $token =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]]; then
    echo "$token_file ne contient pas un jeton de bot Telegram." >&2
    exit 1
  fi

  bot=$(telegram getMe | python3 -c 'import json, sys; print(json.load(sys.stdin)["result"]["username"])')
  echo "Bot : @$bot"

  chat=${RTGRE_TELEGRAM_CHAT_ID:-}
  if [ -z "$chat" ]; then
    chat=$(telegram getUpdates | python3 -c '
import json, sys
chats = [u["message"]["chat"]["id"] for u in json.load(sys.stdin)["result"] if "message" in u]
print(chats[-1] if chats else "")')
  fi
  if ! [[ $chat =~ ^-?[0-9]+$ ]]; then
    echo "Aucune discussion : écrire un message à @$bot dans Telegram, puis relancer." >&2
    exit 1
  fi

  telegram sendMessage --output /dev/null --data-urlencode "chat_id=$chat" \
    --data-urlencode "text=Ce bot est relié à rtgre-platform : les alertes arriveront ici."
  echo "Message de bienvenue envoyé à la discussion $chat."

  # Appliqué côté serveur : kubectl ne recopie pas le contenu du Secret dans une annotation.
  printf '{"apiVersion":"v1","kind":"Secret","metadata":{"name":"%s"},"stringData":{"bot-token":"%s","chat-id":"%s"}}\n' \
    "$secret" "$token" "$chat" |
    remote_kubectl apply --server-side --field-manager rtgre-platform --filename -
  unset token
fi

pod=$(alertmanager_pod)
: "${pod:?Alertmanager ne tourne pas dans $namespace}"

# Le kubelet met jusqu'à deux minutes à présenter un Secret nouveau au pod déjà lancé.
echo "Attente du Secret dans $pod…"
for _ in $(seq 1 30); do
  if remote_kubectl exec "$pod" --container alertmanager -- test -s /etc/alertmanager/telegram/bot-token; then
    mounted=1
    break
  fi
  sleep 5
done
: "${mounted:?Le Secret $secret reste absent de $pod}"

remote_kubectl exec "$pod" --container alertmanager -- amtool alert add EssaiDesAlertes severity=info \
  --annotation "summary=\"Alerte d'essai envoyée par scripts/alertmanager-telegram.sh\"" \
  --annotation "description=\"Rien à faire : la chaîne d'alerte fonctionne.\"" \
  --annotation "runbook_url=\"$runbooks/recevoir-les-alertes.md\"" \
  --alertmanager.url http://127.0.0.1:9093
echo "Alerte d'essai envoyée : le message arrive en moins d'une minute, « Résolu » cinq minutes après."
