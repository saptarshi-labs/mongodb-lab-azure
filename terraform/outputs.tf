output "all_vms" {
  value = {
    for vm_name, def in local.vm_defs : vm_name => {
      set        = def.set
      auth_mode  = def.auth_mode
      role       = def.role
      replset    = def.replset
      ports      = def.ports
      private_ip = azurerm_network_interface.nic[vm_name].private_ip_address
      public_ip  = azurerm_public_ip.pip[vm_name].ip_address
    }
  }
}

output "all_processes" {
  value = merge([
    for vm_name, def in local.vm_defs : {
      for port in def.ports :
      "${vm_name}-${port}" => {
        vm_name    = vm_name
        set        = def.set
        auth_mode  = def.auth_mode
        role       = def.role
        replset    = def.replset
        port       = port
        private_ip = azurerm_network_interface.nic[vm_name].private_ip_address
        public_ip  = azurerm_public_ip.pip[vm_name].ip_address
      }
    }
  ]...)
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "ssh_private_key_path" {
  value = local_file.private_key.filename
}