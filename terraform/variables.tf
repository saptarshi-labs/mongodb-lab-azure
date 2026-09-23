variable "location" {
  default = "southindia"
}

variable "resource_group_name" {
  default = "mongodb-discovery-lab-rg"
}

variable "admin_username" {
  default = "labadmin"
}

# CIDR allowed to SSH/RDP/WinRM in. Defaulted to your current IP, but this
# address is dynamic — re-check with (Invoke-RestMethod -Uri "https://api.ipify.org")
# before each session and override with -var if it has changed.
variable "admin_source_cidr" {
  type    = string
  default = "122.171.17.178/32"
}

variable "vm_size" {
  default = "Standard_D2s_v3"  # 2 vCPU / 8 GB, 5 VMs = 10 vCPU, confirmed quota, mainstream family
}

variable "dc_vm_size" {
  default = "Standard_D2s_v3"  # unused while deploy_ad = false
}

variable "vnet_address_space" {
  default = "10.60.0.0/16"
}

variable "subnet_address_prefix" {
  default = "10.60.1.0/24"
}

variable "mongodb_version" {
  default = "8.0"
}

variable "ad_domain_fqdn" {
  default = "mongolab.local"
}

variable "ad_domain_netbios" {
  default = "MONGOLAB"
}

variable "ad_safe_mode_password" {
  description = "DSRM password for the new forest. Set via TF_VAR_ad_safe_mode_password. Unused while deploy_ad = false, but still required by Terraform since it has no default."
  type        = string
  sensitive   = true
}

variable "dc_private_ip" {
  default = "10.60.1.250"
}

variable "deploy_set2" {
  description = "Set true once the vCPU quota increase clears. Deploys VM7-VM12."
  type        = bool
  default     = false
}

variable "deploy_ad" {
  description = "Set true once the vCPU quota increase clears. Deploys DC1 and runs AD DS install."
  type        = bool
  default     = false
}