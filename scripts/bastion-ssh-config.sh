#!/usr/bin/env bash
# Ouvre une session SSH gérée par le Bastion vers chaque nœud de la prod, puis écrit un fichier
# de configuration SSH qui passe par ces sessions. Ansible et ssh l'utilisent tels quels :
#
#   scripts/bastion-ssh-config.sh
#   ssh -F ansible/.ssh/bastion.conf cp-1
#
# Les sessions expirent après la durée maximale du Bastion : relancer le script pour en rouvrir.
#
# Variables facultatives :
#   RTGRE_SSH_KEY      clé privée de la plateforme (défaut : ~/.ssh/id_ed25519_rtgre_platform)
#   RTGRE_SSH_CONFIG   fichier écrit (défaut : ansible/.ssh/bastion.conf)
#   RTGRE_SESSION_TIMEOUT  attente maximale d'une session, en secondes (défaut : 300)
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
prod="$repo/terraform/envs/prod"
key=${RTGRE_SSH_KEY:-$HOME/.ssh/id_ed25519_rtgre_platform}
config=${RTGRE_SSH_CONFIG:-$repo/ansible/.ssh/bastion.conf}
session_timeout=${RTGRE_SESSION_TIMEOUT:-300}
user=ubuntu

if [ ! -f "$key" ] || [ ! -f "$key.pub" ]; then
  echo "Clé introuvable : $key et $key.pub sont nécessaires." >&2
  exit 1
fi

bastion=$(terraform -chdir="$prod" output -json bastion)
bastion_id=$(jq -r '.id' <<< "$bastion")
ttl=$(jq -r '.max_session_ttl_in_seconds' <<< "$bastion")
nodes=$(terraform -chdir="$prod" output -json nodes)

mkdir -p "$(dirname "$config")"
chmod 700 "$(dirname "$config")"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

{
  echo "# Écrit par scripts/bastion-ssh-config.sh le $(date -u '+%Y-%m-%d à %H:%M UTC')."
  echo "# Sessions valables $((ttl / 60)) minutes : relancer le script ensuite."
} > "$tmp"

# Toutes les sessions sont demandées d'abord, puis attendues : Oracle les prépare en parallèle.
declare -A sessions
for hostname in $(jq -r 'keys[]' <<< "$nodes"); do
  instance_id=$(jq -r --arg h "$hostname" '.[$h].id' <<< "$nodes")
  private_ip=$(jq -r --arg h "$hostname" '.[$h].private_ip' <<< "$nodes")

  echo "Demande de session vers $hostname ($private_ip)…" >&2
  sessions[$hostname]=$(oci bastion session create-managed-ssh \
    --bastion-id "$bastion_id" \
    --target-resource-id "$instance_id" \
    --target-private-ip "$private_ip" \
    --target-os-username "$user" \
    --ssh-public-key-file "$key.pub" \
    --session-ttl "$ttl" \
    --display-name "$hostname-$(date -u +%Y%m%dT%H%M%SZ)" \
    --query 'data.id' --raw-output)
done

for hostname in "${!sessions[@]}"; do
  session=${sessions[$hostname]}
  private_ip=$(jq -r --arg h "$hostname" '.[$h].private_ip' <<< "$nodes")

  echo "Attente de la session vers $hostname…" >&2
  state=$(oci bastion session get --session-id "$session" \
    --wait-for-state ACTIVE --wait-for-state DELETED --wait-for-state FAILED \
    --max-wait-seconds "$session_timeout" \
    --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo "TIMEOUT")
  if [ "$state" != "ACTIVE" ]; then
    echo "La session vers $hostname n'est pas active ($state) : vérifier que le plugin Bastion" \
      "tourne sur le nœud et que le Bastion peut joindre son port SSH." >&2
    exit 1
  fi

  # Le jump host du Bastion a la forme <session>@host.bastion.<région>.oci.oraclecloud.com.
  jump=$(oci bastion session get --session-id "$session" \
    --query 'data."ssh-metadata".command' --raw-output \
    | grep -oE 'ocid1\.bastionsession[^@ ]+@host\.bastion\.[a-z0-9.-]+')

  cat >> "$tmp" <<EOF

Host $hostname $private_ip
  HostName $private_ip
  User $user
  IdentityFile $key
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  ProxyCommand ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -W %h:%p -p 22 $jump
EOF
done

install -m 600 "$tmp" "$config"
echo "Configuration écrite dans $config" >&2
