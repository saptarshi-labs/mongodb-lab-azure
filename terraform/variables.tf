variable "location" {
  default = "centralindia"
}

variable "resource_group_name" {
  default = "mongodb-discovery-lab-rg"
}

variable "admin_username" {
  default = "labadmin"
}

# CIDR allowed to SSH/RDP/WinRM in, e.g. "203.0.113.4/32" — your own public IP.
variable "admin_source_cidr" {
  type = string
}

variable "vm_size" {
  default = "Standard_B2ms"  # 2 vCPU / 8 GB, needed for VMs running 3 mongod processes
}

variable "dc_vm_size" {
  default = "Standard_D2s_v3"  # AD DS wants more headroom than a burstable B-series
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
  description = "DSRM password for the new forest. Set via TF_VAR_ad_safe_mode_password, not committed."
  type        = string
  sensitive   = true
}

variable "dc_private_ip" {
  default = "10.60.1.250"
}