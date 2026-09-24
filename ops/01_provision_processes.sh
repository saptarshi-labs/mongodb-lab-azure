#!/usr/bin/env bash
# 01_provision_processes.sh
# Pushes the correct set's keyfile to each VM and generates per-process
# mongod/mongos config, branching on role (standalone/rs0/configsvr/
# shardsvr/mongos) and auth_mode (local/ldap/kerberos).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/../state"
SSH_USER="${SSH_USER:-labadmin}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=accept-new}"
DC1_IP="${DC1_IP:-}"   # set this once DC1 is up; leave empty to skip LDAP/Kerberos blocks

terraform -chdir="$SCRIPT_DIR/../terraform" output -json all_processes > /tmp/all_processes.json

jq -r 'keys[]' /tmp/all_processes.json | while read -r proc_key; do
  proc=$(jq -r ".\"$proc_key\"" /tmp/all_processes.json)
  set_name=$(echo "$proc" | jq -r '.set')
  auth_mode=$(echo "$proc" | jq -r '.auth_mode')
  role=$(echo "$proc" | jq -r '.role')
  replset=$(echo "$proc" | jq -r '.replset')
  public_ip=$(echo "$proc" | jq -r '.public_ip')
  port=$(echo "$proc" | jq -r '.port')

  echo "=== $proc_key ($set_name, $role, port $port) ==="

  keyfile="$STATE_DIR/${set_name}-mongodb-keyfile"
  scp $SSH_OPTS "$keyfile" "${SSH_USER}@${public_ip}:/tmp/mongodb-keyfile"
  ssh $SSH_OPTS "${SSH_USER}@${public_ip}" \
    "sudo mv /tmp/mongodb-keyfile /etc/mongodb-keyfile && sudo chown mongod:mongod /etc/mongodb-keyfile && sudo chmod 400 /etc/mongodb-keyfile"

  config_path="/etc/mongod.conf"
  [ "$role" = "mongos" ] && config_path="/etc/mongos.conf"

  # --- base config, branch by role ---
  base_config=$(cat <<EOF
systemLog:
  destination: file
  path: /var/log/mongodb/$([ "$role" = "mongos" ] && echo mongos.log || echo mongod.log)
  logAppend: true
net:
  port: $port
  bindIp: 0.0.0.0
security:
  clusterAuthMode: keyFile
  keyFile: /etc/mongodb-keyfile
EOF
)
  [ "$role" != "mongos" ] && base_config="$base_config
  authorization: enabled"

  if [ "$role" != "mongos" ]; then
    base_config="storage:
  dbPath: /var/lib/mongodb
$base_config"
  fi

  case "$role" in
    rs0)       base_config="$base_config
replication:
  replSetName: $replset" ;;
    configsvr) base_config="$base_config
replication:
  replSetName: $replset
sharding:
  clusterRole: configsvr" ;;
    shardsvr)  base_config="$base_config
replication:
  replSetName: $replset
sharding:
  clusterRole: shardsvr" ;;
    mongos)    base_config="$base_config
sharding:
  configDB: ${set_name}-configRS/$(echo "$proc" | jq -r '.private_ip'):27017,$(echo "$proc" | jq -r '.private_ip'):27018,$(echo "$proc" | jq -r '.private_ip'):27019" ;;
  esac

  # --- auth_mode branches ---
  if [ "$auth_mode" = "ldap" ] && [ -n "$DC1_IP" ]; then
    base_config="$base_config
  authenticationMechanisms: [\"SCRAM-SHA-1\", \"PLAIN\"]
  ldap:
    servers: \"${DC1_IP}:389\"
    transportSecurity: none
    bind:
      method: simple
      queryUser: \"CN=svc_ldapbind,OU=ServiceAccounts,OU=MongoDB,DC=mongolab,DC=local\"
    authz:
      queryTemplate: \"{USER}?memberOf?base\""
  elif [ "$auth_mode" = "kerberos" ] && [ -n "$DC1_IP" ]; then
    base_config="$base_config
  authenticationMechanisms: [\"SCRAM-SHA-1\", \"GSSAPI\"]"
    # krb5.conf and /etc/mongod.keytab are pushed separately by
    # ops/08_distribute_keytabs.ps1, after ad-scripts/03_configure_kerberos.ps1
    # has generated the keytabs on DC1. This script only sets the mechanism.
  fi

  echo "$base_config" | ssh $SSH_OPTS "${SSH_USER}@${public_ip}" "sudo tee $config_path > /dev/null"
  ssh $SSH_OPTS "${SSH_USER}@${public_ip}" "sudo systemctl restart $([ "$role" = "mongos" ] && echo mongos || echo mongod)"
done