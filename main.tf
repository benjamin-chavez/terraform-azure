# terraform-azure\main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "tf-rg" {
  name = "tf-resources"
  # location = "us-west-2"
  location = "westus2"

  tags = {
    environment = "development"
  }
}

resource "azurerm_virtual_network" "tf-vn" {
  name                = "tf-network"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "development"
  }
}



resource "azurerm_subnet" "tf-subnet" {
  name                 = "tf-subnet"
  resource_group_name  = azurerm_resource_group.tf-rg.name
  virtual_network_name = azurerm_virtual_network.tf-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "tf-sg" {
  name                = "tf-sg"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name

  tags = {
    environment = "development"
  }
}

resource "azurerm_network_security_rule" "tf-sr" {
  name                        = "tf-sr"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tf-rg.name
  network_security_group_name = azurerm_network_security_group.tf-sg.name
}


resource "azurerm_storage_account" "tf-sa" {
  name                            = "tfstorageaccount1"
  resource_group_name             = azurerm_resource_group.tf-rg.name
  location                        = azurerm_resource_group.tf-rg.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  account_kind                    = "StorageV2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = true

  tags = {
    environment = "development"
  }
}

resource "azurerm_subnet_network_security_group_association" "tf-sga" {
  subnet_id                 = azurerm_subnet.tf-subnet.id
  network_security_group_id = azurerm_network_security_group.tf-sg.id
}

resource "azurerm_public_ip" "tf-ip" {
  name                = "tf-ip-1"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "development"
  }
}


resource "azurerm_network_interface" "tf-nic" {
  name                = "tf-nic"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tf-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf-ip.id
  }

  tags = {
    environment = "development"
  }
}

#  ssh-keygen -t rsa

resource "azurerm_linux_virtual_machine" "tf-vm" {
  name                  = "tf-vm"
  resource_group_name   = azurerm_resource_group.tf-rg.name
  location              = azurerm_resource_group.tf-rg.location
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.tf-nic.id]

  # Setting up docker on the vm
  custom_data = filebase64("./customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/tfazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      # command = templatefile("windows-ssh-script.tpl", {
      hostname     = self.public_ip_address
      user         = "adminuser",
      IdentityFile = "~/.ssh/tfazurekey"
    })

    # Windows
    # interpreter = ["Powershell", "-Command"]

    # Linux
    # interpreter = ["bash", "-c"]

    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = "development"
  }
}


# terraform state list
# terraform state show azurerm_linux_virtual_machine.tf-vm
# ssh -i 'c:\Users\windowsuser\.ssh\tfazurekey' adminuser@xx.xx.xxx.xx
# lsb_release -a

data "azurerm_public_ip" "tf-ip-data" {
  name                = azurerm_public_ip.tf-ip.name
  resource_group_name = azurerm_resource_group.tf-rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.tf-vm.name}: ${data.azurerm_public_ip.tf-ip-data.ip_address}"
}
