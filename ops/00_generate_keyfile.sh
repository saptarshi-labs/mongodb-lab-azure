#!/usr/bin/env bash
set -euo pipefail
mkdir -p ../state
openssl rand -base64 756 > ../state/set1-mongodb-keyfile
openssl rand -base64 756 > ../state/set2-mongodb-keyfile
chmod 400 ../state/set1-mongodb-keyfile ../state/set2-mongodb-keyfile
echo "keyfiles written to ../state/set1-mongodb-keyfile and ../state/set2-mongodb-keyfile"