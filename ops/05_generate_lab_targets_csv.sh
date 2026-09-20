#!/usr/bin/env bash
set -euo pipefail
cd ../terraform
ALL_PROC_JSON="$(terraform output -json all_processes)"
cd - >/dev/null

echo "host,port,label"
echo "$ALL_PROC_JSON" | jq -r 'to_entries[] | [.value.public_ip, .value.port, .key] | @csv'