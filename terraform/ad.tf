# ad.tf
# DC1: Windows Server Active Directory Domain Controller for the lab.
# Serves as the LDAP server for Set2 and, once Kerberos is configured on
# it via ad-scripts/03_configure_kerberos.ps1, as the KDC for Set3.
# Entirely gated behind var.deploy_ad, so a Set1-only run never
# provisions it.

resource "random_password" "ad_admin_password" {
  count            = var.deploy_ad ? 1 : 0
  length           = 20
  special          = true
  override_special = "!@#$%*()-_=+"
}

resource "local_file" "ad_admin_password" {
  count           = var.deploy_ad ? 1 : 0
  content         = random_password.ad_admin_password[0].result
  filename        = "${path.module}/../state/dc1_admin_password.txt"
  file_permission = "0600"
}

resource "azurerm_public_ip" "dc1_pip" {
  count               = var.deploy_ad ? 1 : 0
  name                = "dc1-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dc1_nic" {
  count               = var.deploy_ad ? 1 : 0
  name                = "dc1-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.dc_private_ip
    public_ip_address_id          = azurerm_public_ip.dc1_pip[0].id
  }
}

resource "azurerm_network_interface_security_group_association" "dc1_nic_nsg" {
  count                     = var.deploy_ad ? 1 : 0
  network_interface_id      = azurerm_network_interface.dc1_nic[0].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "dc1" {
  count               = var.deploy_ad ? 1 : 0
  name                = "dc1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = var.dc_vm_size
  admin_username      = var.admin_username
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

  tags = {
    role = "domain-controller"
  }
}

resource "azurerm_virtual_machine_extension" "dc1_install_adds" {
  count                = var.deploy_ad ? 1 : 0
  name                 = "install-adds"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc1[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -EncodedCommand ${base64encode(templatefile("${path.module}/ad-scripts/01_install_adds.ps1", {
      domain_fqdn        = var.ad_domain_fqdn
      domain_netbios     = var.ad_domain_netbios
      safe_mode_password = var.ad_safe_mode_password
    }))}"
  })

  depends_on = [azurerm_windows_virtual_machine.dc1]
}

# Fails terraform plan early if Set2 or Set3 is requested without the AD DC,
# rather than failing halfway through apply.
resource "null_resource" "ad_dependency_check" {
  count = (var.deploy_set2 || var.deploy_set3) && !var.deploy_ad ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: deploy_set2 or deploy_set3 is true but deploy_ad is false. Both require the AD DC.' && exit 1"
  }
}