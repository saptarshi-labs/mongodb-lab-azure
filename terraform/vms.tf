# vms.tf
# Linux mongod/mongos VMs for all three lab sets. Each VM hosts one
# deployment role; a VM listing more than one port runs multiple mongod
# processes on it (replica set members / config servers / shard members
# sharing one host, same multi-process pattern used throughout the lab).
#
#   Set1 (VM1-VM5):   local SCRAM authentication            -> 10.60.2.x
#   Set2 (VM6-VM10):  external authentication via LDAP bind -> 10.60.3.x
#   Set3 (VM11-VM15): external authentication via Kerberos  -> 10.60.4.x
#
# NOTE: this reconstructs the map from our design notes. Check the
# resource names referenced below (azurerm_resource_group.rg,
# azurerm_subnet.subnet, azurerm_network_security_group.nsg,
# tls_private_key.lab_ssh) against whatever your network.tf/main.tf
# actually calls them before running plan.

locals {
  vm_defs_all = {
    # --- Set1: local authentication ---
    VM1 = { set = "set1", auth_mode = "local", role = "standalone", replset = null,            ports = [27017],             ip_suffix = 11 }
    VM2 = { set = "set1", auth_mode = "local", role = "rs0",        replset = "set1-rs0",       ports = [27017,27018,27019], ip_suffix = 12 }
    VM3 = { set = "set1", auth_mode = "local", role = "mongos",     replset = null,             ports = [27017],             ip_suffix = 13 }
    VM4 = { set = "set1", auth_mode = "local", role = "configsvr",  replset = "set1-configRS",  ports = [27017,27018,27019], ip_suffix = 14 }
    VM5 = { set = "set1", auth_mode = "local", role = "shardsvr",   replset = "set1-shard0RS",  ports = [27017,27018,27019], ip_suffix = 15 }

    # --- Set2: external authentication via LDAP ---
    VM6  = { set = "set2", auth_mode = "ldap", role = "standalone", replset = null,             ports = [27017],             ip_suffix = 11 }
    VM7  = { set = "set2", auth_mode = "ldap", role = "rs0",        replset = "set2-rs0",       ports = [27017,27018,27019], ip_suffix = 12 }
    VM8  = { set = "set2", auth_mode = "ldap", role = "mongos",     replset = null,             ports = [27017],             ip_suffix = 13 }
    VM9  = { set = "set2", auth_mode = "ldap", role = "configsvr",  replset = "set2-configRS",  ports = [27017,27018,27019], ip_suffix = 14 }
    VM10 = { set = "set2", auth_mode = "ldap", role = "shardsvr",   replset = "set2-shard0RS",  ports = [27017,27018,27019], ip_suffix = 15 }

    # --- Set3: external authentication via Kerberos ---
    VM11 = { set = "set3", auth_mode = "kerberos", role = "standalone", replset = null,            ports = [27017],             ip_suffix = 11 }
    VM12 = { set = "set3", auth_mode = "kerberos", role = "rs0",        replset = "set3-rs0",       ports = [27017,27018,27019], ip_suffix = 12 }
    VM13 = { set = "set3", auth_mode = "kerberos", role = "mongos",     replset = null,             ports = [27017],             ip_suffix = 13 }
    VM14 = { set = "set3", auth_mode = "kerberos", role = "configsvr",  replset = "set3-configRS",  ports = [27017,27018,27019], ip_suffix = 14 }
    VM15 = { set = "set3", auth_mode = "kerberos", role = "shardsvr",   replset = "set3-shard0RS",  ports = [27017,27018,27019], ip_suffix = 15 }
  }

  # Third octet of the private IP per set: set1 -> 10.60.2.x, set2 -> 10.60.3.x, set3 -> 10.60.4.x
  set_subnet_octet = {
    set1 = 2
    set2 = 3
    set3 = 4
  }

  vm_defs = {
    for k, v in local.vm_defs_all : k => v
    if v.set == "set1"
    || (v.set == "set2" && var.deploy_set2)
    || (v.set == "set3" && var.deploy_set3)
  }
}

resource "azurerm_public_ip" "pip" {
  for_each            = local.vm_defs
  name                = "${each.key}-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  for_each            = local.vm_defs
  name                = "${each.key}-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.60.${local.set_subnet_octet[each.value.set]}.${each.value.ip_suffix}"
    public_ip_address_id          = azurerm_public_ip.pip[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  for_each                  = local.vm_defs
  network_interface_id      = azurerm_network_interface.nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = local.vm_defs
  name                = each.key
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.lab_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    lab_set = each.value.set
    role    = each.value.role
  }
}

output "all_vms" {
  value = { for k, v in azurerm_linux_virtual_machine.vm : k => v.name }
}

output "all_processes" {
  value = merge([
    for vm_key, def in local.vm_defs : {
      for port in def.ports :
      "${vm_key}-${port}" => {
        set        = def.set
        auth_mode  = def.auth_mode
        role       = def.role
        replset    = def.replset
        public_ip  = azurerm_public_ip.pip[vm_key].ip_address
        private_ip = "10.60.${local.set_subnet_octet[def.set]}.${def.ip_suffix}"
        port       = port
      }
    }
  ]...)
}