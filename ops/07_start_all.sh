#!/usr/bin/env bash
set -euo pipefail

cd ../terraform
ALL_VMS_JSON="$(terraform output -json all_vms)"
RG="$(terraform output -raw resource_group_name 2>/dev/null || echo "mongodb-discovery-lab-rg")"
cd - >/dev/null

echo "$ALL_VMS_JSON" | jq -r 'keys[]' | while read -r vm; do
  echo "starting $vm"
  az vm start --resource-group "$RG" --name "$vm" --no-wait
done

echo "start requests submitted. wait ~1-2min then check:"
echo "  az vm list -d -g $RG -o table"
echo "mongod/mongos services are set to auto-start on boot, so no need to re-run ops/01 after a restart."