#!/usr/bin/env bash
set -eux

apt-get update -y
apt-get install -y gnupg curl jq libsasl2-modules-ldap

curl -fsSL https://pgp.mongodb.com/server-${mongodb_version}.asc | \
  gpg --dearmor -o /usr/share/keyrings/mongodb-enterprise.gpg

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-enterprise.gpg ] https://repo.mongodb.com/apt/ubuntu jammy/mongodb-enterprise/${mongodb_version} multiverse" \
  > /etc/apt/sources.list.d/mongodb-enterprise.list

apt-get update -y
apt-get install -y mongodb-enterprise mongodb-enterprise-server mongodb-enterprise-mongos mongodb-enterprise-tools

systemctl stop mongod || true
systemctl disable mongod || true

mkdir -p /etc/mongodb-lab /var/log/mongodb-lab /var/run/mongodb-lab /var/lib/mongodb-lab
echo "${role}" > /etc/mongodb-lab/role

cat > /etc/systemd/system/mongod@.service << 'UNIT'
[Unit]
Description=MongoDB Database Server (port %i)
After=network.target

[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --config /etc/mongodb-lab/mongod-%i.conf
PIDFile=/var/run/mongodb-lab/mongod-%i.pid
Restart=on-failure
LimitNOFILE=64000

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/mongos@.service << 'UNIT'
[Unit]
Description=MongoDB Router (port %i)
After=network.target

[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongos --config /etc/mongodb-lab/mongos-%i.conf
PIDFile=/var/run/mongodb-lab/mongos-%i.pid
Restart=on-failure
LimitNOFILE=64000

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload

useradd -m -s /bin/bash svc_dbbackup || true
usermod -aG sudo svc_dbbackup 2>/dev/null || true
useradd -m -s /bin/bash appreadonly || true