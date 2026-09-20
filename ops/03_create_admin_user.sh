#!/usr/bin/env bash
set -euo pipefail

cd ../terraform
ALL_PROC_JSON="$(terraform output -json all_processes)"
cd - >/dev/null

SSHKEY="$(pwd)/../state/lab_ssh_key.pem"
ADMIN_USER="labadmin"

read -rsp "Set password for lab Mongo admin user 'labMongoAdmin' (used on both sets): " MONGO_ADMIN_PASS
echo

create_admin_on() {
  local ip="$1" port="$2"
  ssh -i "$SSHKEY" -o StrictHostKeyChecking=no "${ADMIN_USER}@${ip}" "
    mongosh --port ${port} --quiet --eval '
      db.getSiblingDB(\"admin\").createUser({
        user: \"labMongoAdmin\",
        pwd: \"${MONGO_ADMIN_PASS}\",
        roles: [{ role: \"root\", db: \"admin\" }]
      })
    '
  "
}

for set in set1 set2; do
  standalone_ip=$(echo "$ALL_PROC_JSON" | jq -r --arg s "$set" '[.[] | select(.set==$s and .role=="standalone")][0].public_ip')
  standalone_port=$(echo "$ALL_PROC_JSON" | jq -r --arg s "$set" '[.[] | select(.set==$s and .role=="standalone")][0].port')
  echo "creating admin on ${set} standalone $standalone_ip:$standalone_port"
  create_admin_on "$standalone_ip" "$standalone_port"

  rs0_ip=$(echo "$ALL_PROC_JSON" | jq -r --arg rs "${set}-rs0" '[.[] | select(.replset==$rs)][0].public_ip')
  rs0_port=$(echo "$ALL_PROC_JSON" | jq -r --arg rs "${set}-rs0" '[.[] | select(.replset==$rs)][0].port')
  echo "creating admin on ${set}-rs0 $rs0_ip:$rs0_port"
  create_admin_on "$rs0_ip" "$rs0_port"

  cfg_ip=$(echo "$ALL_PROC_JSON" | jq -r --arg rs "${set}-configRS" '[.[] | select(.replset==$rs)][0].public_ip')
  cfg_port=$(echo "$ALL_PROC_JSON" | jq -r --arg rs "${set}-configRS" '[.[] | select(.replset==$rs)][0].port')
  echo "creating admin on ${set}-configRS $cfg_ip:$cfg_port"
  create_admin_on "$cfg_ip" "$cfg_port"
done

echo "admin user created on both sets' standalone, rs0, and configRS."