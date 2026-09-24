#!/usr/bin/env bash
# 04_add_shards.sh
# Starts each set's mongos and runs sh.addShard() for that set's shard
# replica set. Generic over set_name, so Set3 needs no special casing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_PASSWORD="${LAB_MONGO_ADMIN_PASSWORD:?set LAB_MONGO_ADMIN_PASSWORD before running}"

terraform -chdir="$SCRIPT_DIR/../terraform" output -json all_processes > /tmp/all_processes.json

for set_name in set1 set2 set3; do
  mongos_target=$(jq -r --arg s "$set_name" \
    'to_entries[] | select(.value.set == $s and .value.role == "mongos") | .value.public_ip + ":" + (.value.port|tostring)' \
    /tmp/all_processes.json)
  [ -z "$mongos_target" ] && { echo "[skip] $set_name not deployed"; continue; }

  shard_hosts=$(jq -r --arg s "$set_name" \
    'to_entries[] | select(.value.set == $s and .value.role == "shardsvr") | .value.private_ip + ":" + (.value.port|tostring)' \
    /tmp/all_processes.json | paste -sd, -)
  shard_replset="${set_name}-shard0RS"

  host="${mongos_target%%:*}"
  port="${mongos_target##*:}"
  echo "=== adding shard on $set_name mongos ($host:$port) ==="
  mongosh --host "$host" --port "$port" -u labMongoAdmin -p "$ADMIN_PASSWORD" --authenticationDatabase admin --eval "
    sh.addShard('${shard_replset}/${shard_hosts}');
  "
done