Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment

$SafeModePwd = ConvertTo-SecureString "${safe_mode_password}" -AsPlainText -Force

Install-ADDSForest `
  -DomainName "${domain_fqdn}" `
  -DomainNetbiosName "${domain_netbios}" `
  -SafeModeAdministratorPassword $SafeModePwd `
  -InstallDns:$true `
  -Force:$true `
  -NoRebootOnCompletion:$false