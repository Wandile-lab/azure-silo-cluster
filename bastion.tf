resource "azurerm_network_interface" "bastion_nic" {
  name                = "nic-bastion"
  location            = azurerm_resource_group.acumen.location
  resource_group_name = azurerm_resource_group.acumen.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "bastion_vm" {
  vm_agent_platform_updates_enabled = true
  name                              = "vm-acumen-bastion"
  resource_group_name               = azurerm_resource_group.acumen.name
  location                          = azurerm_resource_group.acumen.location
  size                              = "Standard_D2s_v4"
  admin_username                    = "acumenadmin"

  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id,
  ]

  admin_ssh_key {
    username   = "acumenadmin"
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  disable_password_authentication = true
}

output "bastion_public_ip" {
  value       = azurerm_public_ip.bastion_pip.ip_address
  description = "The public IP address of the Bastion Host"
}
