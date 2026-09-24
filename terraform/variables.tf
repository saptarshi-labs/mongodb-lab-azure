variable "location" {
  description = "Azure region for the lab"
  type        = string
  default     = "southindia"
}

variable "resource_group_name" {
  description = "Resource group name for the lab"
  type        = string
  default     = "mongodb-discovery-lab-rg"
}

variable "admin_username" {
  description = "Local admin username for all VMs"
  type        = string
  default     = "labadmin"
}

variable "admin_source_cidr" {
  description = "Your current public IP. Restricts SSH/RDP/NSG rules to just you."
  type        = string
  default     = "122.171.17.112/32"
}

variable "vm_size" {
  description = "VM size for all Linux mongod/mongos VMs across Set1, Set2, Set3"
  type        = string
  default     = "Standard_D2alds_v6"
}

variable "dc_vm_size" {
  description = "VM size for the Windows AD Domain Controller (DC1). NOT yet validated in southindia, test with the same 3-step CLI check before applying."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "mongodb_version" {
  description = "MongoDB Enterprise version to install"
  type        = string
  default     = "8.0"
}

variable "ad_domain_fqdn" {
  description = "AD domain FQDN"
  type        = string
  default     = "mongolab.local"
}

variable "ad_domain_netbios" {
  description = "AD domain NetBIOS name"
  type        = string
  default     = "MONGOLAB"
}

variable "ad_safe_mode_password" {
  description = "AD DS Safe Mode admin password. Set via TF_VAR_ad_safe_mode_password, never commit a real value here."
  type        = string
  sensitive   = true
  default     = "unused-for-now"
}

variable "dc_private_ip" {
  description = "Static private IP for DC1. Also acts as the KDC once deploy_set3 is enabled, no separate VM needed for Kerberos."
  type        = string
  default     = "10.60.1.250"
}

variable "deploy_ad" {
  description = "Deploy the DC1 Windows AD Domain Controller. Required if deploy_set2 or deploy_set3 is true."
  type        = bool
  default     = false
}

variable "deploy_set2" {
  description = "Deploy Set2 (external authentication via LDAP)"
  type        = bool
  default     = false
}

variable "deploy_set3" {
  description = "Deploy Set3 (external authentication via Kerberos). Requires deploy_ad = true."
  type        = bool
  default     = false
}