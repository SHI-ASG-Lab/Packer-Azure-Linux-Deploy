# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.88.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Variable Declarations

variable "RG_Env_Tag" {
    type = string
}
variable "RG_SP_Name" {
  type = string
}
variable "Requestor" {
  type = string
  default = "nil"
}
variable "Owner" {
  type = string
  default = "nil"
}
variable "ExistingImageName" {
    type = string
}
variable "VmName" {
    type = string
}
variable "NumUbuntu" {
    type = number
    default = 1
}
locals {
  common_tags = {
    Owner       = var.Owner
    Requestor   = var.Requestor
    Environment = var.RG_Env_Tag
    SP          = var.RG_SP_Name
  }
}

# Reference Existing Image

data "azurerm_image" "custom" {
  resource_group_name = "LAB-PackerImages"
  name                = var.ExistingImageName
}

# Reference Existing Resource Group

data "azurerm_resource_group" "main" {
  name = "LAB-PackerImages"
}

# Reference Existing Virtual Network

data "azurerm_virtual_network" "main" {
  name                = "LAB-PackerImages-vnet"
  resource_group_name = data.azurerm_resource_group.main.name
}

# Reference Existing Subnet

data "azurerm_subnet" "default" {
  name                 = "default"
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_resource_group.main.name
}

# Create a public IP for the system to use

resource "azurerm_public_ip" "azPubIp" {
  name = "${var.VmName}-PubIp1"
  resource_group_name = data.azurerm_resource_group.main.name
  location = data.azurerm_resource_group.main.location
  allocation_method = "Static"
}

# Create NIC for the VM

resource "azurerm_network_interface" "main" {
  name                = "${var.VmName}-nic1"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = data.azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    # private_ip_address            = "10.28.0.10"
    public_ip_address_id          = azurerm_public_ip.azPubIp.id
    primary                       = true
  }
}

# Create Virtual Machine

resource "azurerm_virtual_machine" "main" {
  name                         = var.VmName
  location                     = data.azurerm_resource_group.main.location
  resource_group_name          = data.azurerm_resource_group.main.name
  network_interface_ids        = [azurerm_network_interface.main.id]
  primary_network_interface_id = azurerm_network_interface.main.id
  vm_size                     = "Standard_E2s_v3"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
   delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.custom.id}"
  }
  storage_os_disk {
    name              = "${var.VmName}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = var.VmName
    admin_username = "testuser"
    admin_password = "SHIisNumber1!"
  }
  #os_profile_linux_config {
  #  disable_password_authentication = false
  #}
  
  os_profile_windows_config {
  }
  
  tags     = local.common_tags
}
