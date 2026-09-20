Import-Module ActiveDirectory

$domainDN = "DC=mongolab,DC=local"

New-ADOrganizationalUnit -Name "MongoDB" -Path $domainDN -ProtectedFromAccidentalDeletion:$false
New-ADOrganizationalUnit -Name "Groups" -Path "OU=MongoDB,$domainDN" -ProtectedFromAccidentalDeletion:$false
New-ADOrganizationalUnit -Name "Users" -Path "OU=MongoDB,$domainDN" -ProtectedFromAccidentalDeletion:$false
New-ADOrganizationalUnit -Name "ServiceAccounts" -Path "OU=MongoDB,$domainDN" -ProtectedFromAccidentalDeletion:$false

$groupsOU = "OU=Groups,OU=MongoDB,$domainDN"
$usersOU  = "OU=Users,OU=MongoDB,$domainDN"
$svcOU    = "OU=ServiceAccounts,OU=MongoDB,$domainDN"

# groups named so they map 1:1 to MongoDB roles in seed_ldap_roles_set2.js
New-ADGroup -Name "MongoDB-Admins"           -GroupScope Global -Path $groupsOU
New-ADGroup -Name "MongoDB-AppDB1-ReadWrite" -GroupScope Global -Path $groupsOU
New-ADGroup -Name "MongoDB-AppDB2-ReadOnly"  -GroupScope Global -Path $groupsOU

# service account mongod itself uses to bind and run the authz query
$svcPwd = ConvertTo-SecureString "SvcLdapBind2026!" -AsPlainText -Force
New-ADUser -Name "svc_ldapbind" -Path $svcOU `
  -AccountPassword $svcPwd -Enabled $true `
  -PasswordNeverExpires $true -CannotChangePassword $true

# test accounts, deliberately named to mirror the ones seeded on Set1, so
# you can compare local-SCRAM vs LDAP-authenticated discovery output for
# what is conceptually the same identity
$testPwd = ConvertTo-SecureString "TestUser2026!" -AsPlainText -Force

New-ADUser -Name "human_saptarshi_test" -Path $usersOU `
  -AccountPassword $testPwd -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "MongoDB-Admins" -Members "human_saptarshi_test"

New-ADUser -Name "svc_ordersapp" -Path $svcOU `
  -AccountPassword $testPwd -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "MongoDB-AppDB1-ReadWrite" -Members "svc_ordersapp"

New-ADUser -Name "svc_reportingapp" -Path $svcOU `
  -AccountPassword $testPwd -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "MongoDB-AppDB2-ReadOnly" -Members "svc_reportingapp"

Write-Output "AD objects created under OU=MongoDB,$domainDN"