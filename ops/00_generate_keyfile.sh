#!/usr/bin/env bash
# 00_generate_keyfile.sh
# Generates one internal-cluster-auth keyfile per set. Kerberos handles
# client authentication for Set3, but internal cluster auth between
# mongod members still uses a keyfile, same as Set1 and Set2.
set -euo pipefail

STATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../state" && pwd)"
mkdir -p "$STATE_DIR"

for set_name in set1 set2 set3; do
  keyfile="$STATE_DIR/${set_name}-mongodb-keyfile"
  if [ -f "$keyfile" ]; then
    echo "  [skip] $keyfile already exists"
    continue
  fi
  openssl rand -base64 756 > "$keyfile"
  chmod 400 "$keyfile"
  echo "  [ok] generated $keyfile"
done