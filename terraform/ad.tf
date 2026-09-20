resource "random_password" "ad_admin_password" {
  count       = var.deploy_ad ? 1 : 0
  length      = 20
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

resource "local_file" "ad_admin_password" {
  count           = var.deploy_ad ? 1 : 0
  content         = random_password.ad_admin_password[0].result
  filename        = "${path.module}/../state/dc1_admin_password.txt"
  file_permission = "0600"
}

resource "azurerm_public_ip" "dc1_pip" {
  count               = var.deploy_ad ? 1 : 0
  name                = "DC1-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dc1_nic" {
  count               = var.deploy_ad ? 1 : 0
  name                = "DC1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.dc_private_ip
    public_ip_address_id          = azurerm_public_ip.dc1_pip[0].id
  }
}

resource "azurerm_windows_virtual_machine" "dc1" {
  count               = var.deploy_ad ? 1 : 0
  name                = "DC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.dc_vm_size
  admin_username      = "labadmin"
  admin_password      = random_password.ad_admin_password[0].result

  network_interface_ids = [azurerm_network_interface.dc1_nic[0].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# Stage 1 only: install AD DS, promote the forest, reboot. Stage 2
# (ad-scripts/02_create_ad_objects.ps1) is run manually once DC1 is
# confirmed back up after the reboot.
resource "azurerm_virtual_machine_extension" "dc1_install_adds" {
  count                = var.deploy_ad ? 1 : 0
  name                 = "install-adds"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc1[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(templatefile("${path.module}/ad-scripts/01_install_adds.ps1", {
      domain_fqdn        = var.ad_domain_fqdn
      domain_netbios     = var.ad_domain_netbios
      safe_mode_password = var.ad_safe_mode_password
    }), "UTF-16LE")}"
  })

  depends_on = [azurerm_windows_virtual_machine.dc1]
}

output "dc1_private_ip" {
  value = var.deploy_ad ? azurerm_network_interface.dc1_nic[0].private_ip_address : null
}

output "dc1_public_ip" {
  value = var.deploy_ad ? azurerm_public_ip.dc1_pip[0].ip_address : null
}

output "dc1_admin_password_file" {
  value = var.deploy_ad ? local_file.ad_admin_password[0].filename : null
}