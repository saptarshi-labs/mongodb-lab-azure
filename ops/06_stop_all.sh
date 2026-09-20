#!/usr/bin/env bash
set -euo pipefail

cd ../terraform
ALL_VMS_JSON="$(terraform output -json all_vms)"
RG="$(terraform output -raw resource_group_name 2>/dev/null || echo "mongodb-discovery-lab-rg")"
cd - >/dev/null

echo "$ALL_VMS_JSON" | jq -r 'keys[]' | while read -r vm; do
  echo "stopping $vm"
  az vm stop --resource-group "$RG" --name "$vm" --no-wait
done

echo "stop requests submitted for all VMs. check progress with:"
echo "  az vm list -d -g $RG -o table"
echo "note: guest OS is off, compute billing continues (this is stop, not deallocate)."