# 03_configure_kerberos.ps1
# Creates the mongod service account, registers one SPN per Set3 host,
# and generates a keytab per host for GSSAPI authentication.
param(
  [string]$DomainFqdn = "mongolab.local",
  [string[]]$Set3Hostnames = @("vm11.mongolab.local","vm12.mongolab.local","vm13.mongolab.local","vm14.mongolab.local","vm15.mongolab.local")
)

$SvcAccount = "svc_mongodb"
$SvcPassword = "SvcMongodKrb2026!"   # lab-only, not production-safe
$OU = "OU=ServiceAccounts,OU=MongoDB,DC=mongolab,DC=local"

New-ADUser -Name $SvcAccount -SamAccountName $SvcAccount `
  -UserPrincipalName "$SvcAccount@$DomainFqdn" `
  -Path $OU -AccountPassword (ConvertTo-SecureString $SvcPassword -AsPlainText -Force) `
  -PasswordNeverExpires $true -Enabled $true

foreach ($hostname in $Set3Hostnames) {
  $spn = "mongodb/$hostname"
  setspn -A $spn $SvcAccount

  $keytabFile = "C:\keytabs\$hostname.keytab"
  New-Item -ItemType Directory -Force -Path "C:\keytabs" | Out-Null
  ktpass -princ "$spn@$($DomainFqdn.ToUpper())" -mapuser "$SvcAccount@$DomainFqdn" `
    -pass $SvcPassword -out $keytabFile -ptype KRB5_NT_PRINCIPAL -crypto AES256-SHA1
}

Write-Output "Keytabs generated under C:\keytabs on DC1. Retrieve them and distribute to each Set3 host at /etc/mongod.keytab."