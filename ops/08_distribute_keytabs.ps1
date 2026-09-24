# 08_distribute_keytabs.ps1
# Pulls the generated keytabs off DC1 and pushes each one, plus a
# krb5.conf, to its matching Set3 Linux VM.
param(
  [string]$DC1PublicIp,
  [hashtable]$Set3HostIps  # e.g. @{ "vm11.mongolab.local" = "20.x.x.x"; ... }
)

foreach ($hostname in $Set3HostIps.Keys) {
  $localKeytab = ".\keytabs\$hostname.keytab"

  # Pull from DC1 (adjust to however you're already retrieving files
  # from DC1, e.g. az vm run-command with a download step, or RDP copy).

  $targetIp = $Set3HostIps[$hostname]
  scp -o StrictHostKeyChecking=accept-new $localKeytab "labadmin@${targetIp}:/tmp/mongod.keytab"
  ssh "labadmin@${targetIp}" "sudo mv /tmp/mongod.keytab /etc/mongod.keytab && sudo chown mongod:mongod /etc/mongod.keytab && sudo chmod 400 /etc/mongod.keytab"

  $krb5Conf = @"
[libdefaults]
  default_realm = MONGOLAB.LOCAL

[realms]
  MONGOLAB.LOCAL = {
    kdc = 10.60.1.250
  }

[domain_realm]
  .mongolab.local = MONGOLAB.LOCAL
"@
  $krb5Conf | ssh "labadmin@${targetIp}" "sudo tee /etc/krb5.conf > /dev/null"
}