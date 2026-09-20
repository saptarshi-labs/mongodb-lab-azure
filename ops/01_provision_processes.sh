#!/usr/bin/env bash
set -euo pipefail

cd ../terraform
ALL_VMS_JSON="$(terraform output -json all_vms)"
ALL_PROC_JSON="$(terraform output -json all_processes)"
DC1_IP="$(terraform output -raw dc1_private_ip 2>/dev/null || echo "")"
cd - >/dev/null

SSHKEY="$(pwd)/../state/lab_ssh_key.pem"
ADMIN_USER="labadmin"
LDAP_BIND_DN="CN=svc_ldapbind,OU=ServiceAccounts,OU=MongoDB,DC=mongolab,DC=local"
LDAP_BIND_PW="SvcLdapBind2026!"   # matches 02_create_ad_objects.ps1 — move to a secret store beyond lab use

ssh_do() { ssh -i "$SSHKEY" -o StrictHostKeyChecking=no "${ADMIN_USER}@$1" "${@:2}"; }
scp_do() { scp -i "$SSHKEY" -o StrictHostKeyChecking=no "$1" "${ADMIN_USER}@$2:$3"; }

echo "$ALL_VMS_JSON" | jq -r 'to_entries[] | [.key, .value.set, .value.public_ip] | @tsv' | while IFS=$'\t' read -r vm set ip; do
  keyfile="../state/${set}-mongodb-keyfile"
  echo "pushing $keyfile to $vm ($ip)"
  scp_do "$keyfile" "$ip" "/tmp/mongodb-keyfile"
  ssh_do "$ip" '
    sudo mv /tmp/mongodb-keyfile /etc/mongodb-lab/mongodb-keyfile
    sudo chown mongodb:mongodb /etc/mongodb-lab/mongodb-keyfile
    sudo chmod 400 /etc/mongodb-lab/mongodb-keyfile
  '
done

echo "$ALL_PROC_JSON" | jq -r 'to_entries[] | @base64' | while read -r row; do
  entry() { echo "$row" | base64 --decode | jq -r "$1"; }
  proc_name=$(entry '.key')
  role=$(entry '.value.role')
  replset=$(entry '.value.replset')
  port=$(entry '.value.port')
  public_ip=$(entry '.value.public_ip')
  auth_mode=$(entry '.value.auth_mode')

  echo "== $proc_name ($role, $auth_mode) on $public_ip:$port =="

  ssh_do "$public_ip" "sudo mkdir -p /var/lib/mongodb-lab/${port} && sudo chown mongodb:mongodb /var/lib/mongodb-lab/${port}"

  ldap_block=""
  auth_mech_line=""
  if [ "$auth_mode" = "ldap" ] && [ "$role" != "standalone" ] && [ -n "$DC1_IP" ]; then
    auth_mech_line="  authenticationMechanisms: [\"SCRAM-SHA-1\",\"PLAIN\"]"
    ldap_block=$(cat << EOF
  ldap:
    servers: "${DC1_IP}:389"
    transportSecurity: none
    bind:
      queryUser: "${LDAP_BIND_DN}"
      queryPassword: "${LDAP_BIND_PW}"
    userToDNMapping: '[{match: "(.+)", substitution: "CN={0},OU=Users,OU=MongoDB,DC=mongolab,DC=local"}]'
    authz:
      queryTemplate: "OU=MongoDB,DC=mongolab,DC=local??sub?(&(objectClass=user)(sAMAccountName={USER}))"
EOF
)
  fi

  if [ "$role" = "mongos" ]; then
    {
      echo "net:"
      echo "  bindIp: 0.0.0.0"
      echo "  port: ${port}"
      echo "systemLog:"
      echo "  destination: file"
      echo "  path: /var/log/mongodb-lab/mongos-${port}.log"
      echo "  logAppend: true"
      echo "security:"
      echo "  keyFile: /etc/mongodb-lab/mongodb-keyfile"
      [ -n "$auth_mech_line" ] && echo "$auth_mech_line"
      [ -n "$ldap_block" ] && echo "$ldap_block"
    } > /tmp/proc.conf
    remote_name="mongos-${port}.conf"
    service="mongos@${port}"
  else
    sharding_block=""
    [ "$role" = "configsvr" ] && sharding_block=$'sharding:\n  clusterRole: configsvr'
    [ "$role" = "shardsvr" ]  && sharding_block=$'sharding:\n  clusterRole: shardsvr'

    repl_block=""
    if [ "$role" != "standalone" ]; then
      repl_block=$'replication:\n  replSetName: '"${replset}"
    fi

    {
      echo "net:"
      echo "  bindIp: 0.0.0.0"
      echo "  port: ${port}"
      echo "storage:"
      echo "  dbPath: /var/lib/mongodb-lab/${port}"
      # multi-process hosts (every non-standalone role in this topology runs
      # 3 mongod processes on one small VM) need a small explicit cache,
      # otherwise each process assumes it owns the whole box and OOMs
      if [ "$role" != "standalone" ]; then
        echo "  wiredTiger:"
        echo "    engineConfig:"
        echo "      cacheSizeGB: 0.25"
      fi
      echo "systemLog:"
      echo "  destination: file"
      echo "  path: /var/log/mongodb-lab/mongod-${port}.log"
      echo "  logAppend: true"
      [ -n "$repl_block" ] && echo "$repl_block"
      [ -n "$sharding_block" ] && echo "$sharding_block"
      echo "security:"
      if [ "$role" = "standalone" ]; then
        echo "  authorization: enabled"
      else
        echo "  keyFile: /etc/mongodb-lab/mongodb-keyfile"
      fi
      [ -n "$auth_mech_line" ] && echo "$auth_mech_line"
      [ -n "$ldap_block" ] && echo "$ldap_block"
      echo "processManagement:"
      echo "  fork: false"
    } > /tmp/proc.conf
    remote_name="mongod-${port}.conf"
    service="mongod@${port}"
  fi

  scp_do /tmp/proc.conf "$public_ip" "/tmp/${remote_name}"
  ssh_do "$public_ip" "sudo mv /tmp/${remote_name} /etc/mongodb-lab/${remote_name} && sudo systemctl daemon-reload"

  if [ "$role" != "mongos" ]; then
    ssh_do "$public_ip" "sudo systemctl enable ${service} && sudo systemctl restart ${service}"
  fi
done

echo "all mongod processes configured and started. mongos config written but not started, see 04."