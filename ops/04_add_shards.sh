#!/usr/bin/env bash
set -euo pipefail

cd ../terraform
ALL_PROC_JSON="$(terraform output -json all_processes)"
cd - >/dev/null

SSHKEY="$(pwd)/../state/lab_ssh_key.pem"
ADMIN_USER="labadmin"

read -rsp "Enter labMongoAdmin password: " MONGO_ADMIN_PASS
echo

for set in set1 set2; do
  mongos_ip=$(echo "$ALL_PROC_JSON" | jq -r --arg s "$set" '[.[] | select(.set==$s and .role=="mongos")][0].public_ip')
  mongos_port=$(echo "$ALL_PROC_JSON" | jq -r --arg s "$set" '[.[] | select(.set==$s and .role=="mongos")][0].port')

  configdb_string=$(echo "$ALL_PROC_JSON" | jq -r --arg rs "${set}-configRS" '
    [.[] | select(.replset==$rs)] |
    ($rs + "/" + ( map(.private_ip + ":" + (.port|tostring)) | join(",") ))
  ')

  echo "== ${set}: configDB=$configdb_string, starting mongos on $mongos_ip:$mongos_port =="
  ssh -i "$SSHKEY" -o StrictHostKeyChecking=no "${ADMIN_USER}@${mongos_ip}" "
    printf 'sharding:\n  configDB: ${configdb_string}\n' | sudo tee -a /etc/mongodb-lab/mongos-${mongos_port}.conf >/dev/null
    sudo systemctl enable mongos@${mongos_port}
    sudo systemctl restart mongos@${mongos_port}
  "
  sleep 10

  for rs in $(echo "$ALL_PROC_JSON" | jq -r --arg s "$set" '[.[] | select(.set==$s and .role=="shardsvr") | .replset] | unique | .[]'); do
    members=$(echo "$ALL_PROC_JSON" | jq -r --arg rs "$rs" '
      [.[] | select(.replset==$rs)] | map(.private_ip + ":" + (.port|tostring)) | join(",")
    ')
    conn_string="${rs}/${members}"
    echo "adding shard: $conn_string"
    ssh -i "$SSHKEY" -o StrictHostKeyChecking=no "${ADMIN_USER}@${mongos_ip}" "
      mongosh --port ${mongos_port} -u labMongoAdmin -p '${MONGO_ADMIN_PASS}' --authenticationDatabase admin --quiet --eval '
        sh.addShard(\"${conn_string}\")
      '
    "
  done
done

echo "shards added on both sets."