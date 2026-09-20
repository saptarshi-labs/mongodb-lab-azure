resource "tls_private_key" "lab_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.lab_key.private_key_pem
  filename        = "${path.module}/../state/lab_ssh_key.pem"
  file_permission = "0600"
}

locals {
  vm_defs_all = {
    # Set1 — local SCRAM auth only
    "VM1" = { set = "set1", auth_mode = "local", role = "standalone",     replset = null,             ports = [27017] }
    "VM2" = { set = "set1", auth_mode = "local", role = "replica_member", replset = "set1-rs0",       ports = [27017, 27018, 27019] }
    "VM3" = { set = "set1", auth_mode = "local", role = "mongos",         replset = null,             ports = [27020] }
    "VM4" = { set = "set1", auth_mode = "local", role = "configsvr",      replset = "set1-configRS",  ports = [27017, 27018, 27019] }
    "VM5" = { set = "set1", auth_mode = "local", role = "shardsvr",       replset = "set1-shard0RS",  ports = [27017, 27018, 27019] }
    "VM6" = { set = "set1", auth_mode = "local", role = "shardsvr",       replset = "set1-shard1RS",  ports = [27017, 27018, 27019] }

    # Set2 — external auth against DC1 (AD/LDAP)
    "VM7"  = { set = "set2", auth_mode = "ldap", role = "standalone",     replset = null,             ports = [27017] }
    "VM8"  = { set = "set2", auth_mode = "ldap", role = "replica_member", replset = "set2-rs0",       ports = [27017, 27018, 27019] }
    "VM9"  = { set = "set2", auth_mode = "ldap", role = "mongos",         replset = null,             ports = [27020] }
    "VM10" = { set = "set2", auth_mode = "ldap", role = "configsvr",      replset = "set2-configRS",  ports = [27017, 27018, 27019] }
    "VM11" = { set = "set2", auth_mode = "ldap", role = "shardsvr",       replset = "set2-shard0RS",  ports = [27017, 27018, 27019] }
    "VM12" = { set = "set2", auth_mode = "ldap", role = "shardsvr",       replset = "set2-shard1RS",  ports = [27017, 27018, 27019] }
  }

  # while deploy_set2 = false, only Set1's 6 VMs get created
  vm_defs = var.deploy_set2 ? local.vm_defs_all : {
    for k, v in local.vm_defs_all : k => v if v.set == "set1"
  }
}

resource "azurerm_public_ip" "pip" {
  for_each            = local.vm_defs
  name                = "${each.key}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  for_each            = local.vm_defs
  name                = "${each.key}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = local.vm_defs
  name                = each.key
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.lab_key.public_key_openssh
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

  custom_data = base64encode(templatefile("${path.module}/cloud-init/install_mongodb.sh.tpl", {
    role            = each.value.role
    mongodb_version = var.mongodb_version
  }))

  tags = {
    lab_set     = each.value.set
    lab_role    = each.value.role
    lab_replset = coalesce(each.value.replset, "none")
    auth_mode   = each.value.auth_mode
  }
}