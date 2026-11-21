#!/usr/bin/env bash
# Mesure l'usage d'un nœud à travers le Bastion : processeur (occupé et volé par l'hyperviseur),
# charge, mémoire, et les conteneurs qui consomment le plus.
#
#   scripts/bastion-ssh-config.sh
#   scripts/measure-node.sh cp-1 300        # 5 minutes, un échantillon toutes les 5 secondes
#
# Variable facultative :
#   RTGRE_SSH_CONFIG   configuration SSH (défaut : ansible/.ssh/bastion.conf)
set -euo pipefail

host=${1:?Usage : $0 <nœud> [durée en secondes] [intervalle en secondes]}
duration=${2:-300}
interval=${3:-5}
repo=$(git rev-parse --show-toplevel)
config=${RTGRE_SSH_CONFIG:-$repo/ansible/.ssh/bastion.conf}
samples=$((duration / interval))

ssh -F "$config" -o BatchMode=yes "$host" bash -s -- "$interval" "$samples" <<'REMOTE'
set -euo pipefail
interval=$1
samples=$2

echo "# $(hostname) — $(date -u '+%Y-%m-%d %H:%M UTC'), $samples échantillons de $interval s"

# La première ligne de vmstat donne la moyenne depuis le démarrage : elle est ignorée.
# Les colonnes sont repérées par leur nom, qui varie selon la version de vmstat.
vmstat -n "$interval" $((samples + 1)) | awk '
  NR == 2 { for (i = 1; i <= NF; i++) column[$i] = i; next }
  NR > 3 {
    busy = 100 - $column["id"]; stolen = $column["st"]; n++
    busy_sum += busy; if (busy > busy_max) busy_max = busy
    stolen_sum += stolen; if (stolen > stolen_max) stolen_max = stolen
  }
  END {
    printf "Processeur occupé : %.1f %% en moyenne, %d %% au plus\n", busy_sum / n, busy_max
    printf "Temps volé par l hyperviseur : %.1f %% en moyenne, %d %% au plus\n", stolen_sum / n, stolen_max
  }'

awk '{ printf "Charge (1, 5, 15 min) : %s %s %s\n", $1, $2, $3 }' /proc/loadavg
free -m | awk '/^Mem:/ { printf "Mémoire : %d Mo utilisés, %d Mo disponibles sur %d Mo\n", $3, $7, $2 }'

echo "Conteneurs les plus gourmands (instantané) :"
sudo crictl stats -o json | python3 -c '
import json, sys
rows = []
for stat in json.load(sys.stdin)["stats"]:
    if "cpu" not in stat or "memory" not in stat:
        continue  # conteneur arrêté, par exemple un conteneur d initialisation
    labels = stat["attributes"]["labels"]
    cpu = int(stat["cpu"].get("usageNanoCores", {}).get("value", 0)) / 1e6
    memory = int(stat["memory"].get("workingSetBytes", {}).get("value", 0)) / 2**20
    rows.append((memory, cpu, labels["io.kubernetes.pod.name"], labels["io.kubernetes.container.name"]))
for memory, cpu, pod, container in sorted(rows, reverse=True)[:8]:
    print(f"  {memory:7.0f} Mo  {cpu:6.0f} m  {pod}/{container}")
print(f"  Total : {sum(r[0] for r in rows):.0f} Mo, {sum(r[1] for r in rows):.0f} m pour {len(rows)} conteneurs")
'
REMOTE
