#!/usr/bin/env bash
# 03_create_admin_user.sh
# Creates labMongoAdmin (root@admin) on the standalone, rs0, and
# configRS/shard0RS entry points for every deployed set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_PASSWORD="${LAB_MONGO_ADMIN_PASSWORD:?set LAB_MONGO_ADMIN_PASSWORD before running}"

terraform -chdir="$SCRIPT_DIR/../terraform" output -json all_processes > /tmp/all_processes.json

for set_name in set1 set2 set3; do
  entry_points=$(jq -r --arg s "$set_name" \
    'to_entries[] | select(.value.set == $s and (.value.role == "standalone" or (.value.role == "rs0" and .value.port == 27017) or (.value.role == "shardsvr" and .value.port == 27017))) | .value.public_ip + ":" + (.value.port|tostring)' \
    /tmp/all_processes.json)

  [ -z "$entry_points" ] && { echo "[skip] $set_name not deployed"; continue; }

  echo "$entry_points" | while read -r target; do
    host="${target%%:*}"
    port="${target##*:}"
    echo "=== creating labMongoAdmin on $set_name ($host:$port) ==="
    mongosh --host "$host" --port "$port" --eval "
      db.getSiblingDB('admin').createUser({
        user: 'labMongoAdmin',
        pwd: '$ADMIN_PASSWORD',
        roles: [{ role: 'root', db: 'admin' }]
      });
    " || echo "  [warn] user may already exist on $host:$port"
  done
done