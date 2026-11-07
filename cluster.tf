resource "azurerm_network_interface" "cluster_nic" {
  count               = 2
  name                = "nic-cluster-node-${count.index + 1}"
  location            = azurerm_resource_group.acumen.location
  resource_group_name = azurerm_resource_group.acumen.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Static"
    private_ip_address            = count.index == 0 ? "10.0.2.5" : "10.0.2.4"
  }
}

# 2. The Private Cluster Virtual Machines (2 Nodes = 4 vCPUs)
resource "azurerm_linux_virtual_machine" "cluster_vm" {
  vm_agent_platform_updates_enabled = true
  lifecycle {
    ignore_changes = [custom_data]
  }

  count               = 2
  name                = "vm-acumen-node-${count.index + 1}"
  resource_group_name = azurerm_resource_group.acumen.name
  location            = azurerm_resource_group.acumen.location
  size                = "Standard_E2ds_v4"
  admin_username      = "acumenadmin"
  custom_data         = filebase64("bootstrap.sh")

  network_interface_ids = [
    azurerm_network_interface.cluster_nic[count.index].id,
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

# 3. Four Dedicated Managed Disks (40GB Total Pool)
resource "azurerm_managed_disk" "cluster_data" {
  count                = 4
  name                 = "disk-acumen-data-${count.index + 1}"
  location             = azurerm_resource_group.acumen.location
  resource_group_name  = azurerm_resource_group.acumen.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

# 4. Attach 2 Disks to Each VM (Node 1 gets Disks 1 & 3, Node 2 gets Disks 2 & 4)
resource "azurerm_virtual_machine_data_disk_attachment" "cluster_data_attach" {
  count              = 4
  managed_disk_id    = azurerm_managed_disk.cluster_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.cluster_vm[count.index % 2].id
  lun                = 10 + floor(count.index / 2)
  caching            = "ReadWrite"
}

# 5. Output the Private IPs
output "cluster_private_ips" {
  value       = azurerm_linux_virtual_machine.cluster_vm[*].private_ip_address
  description = "The private IP addresses of the Cluster Nodes"
}
