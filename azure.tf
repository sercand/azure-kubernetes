resource "azurerm_resource_group" "az_kube" {
  name     = "${var.deployid}"
  location = "${var.location}"
}

resource "azurerm_storage_account" "az_kube" {
  name                = "${var.deployid}stra"
  resource_group_name = "${azurerm_resource_group.az_kube.name}"
  location            = "${var.location}"
  account_type        = "Standard_LRS"
}

resource "azurerm_storage_container" "az_kube" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.az_kube.name}"
  storage_account_name  = "${azurerm_storage_account.az_kube.name}"
  container_access_type = "private"
}

resource "azurerm_network_security_group" "az_kube" {
  name                = "${var.deployid}-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.az_kube.name}"
}

resource "azurerm_network_security_rule" "az_kube_allow_ssh" {
  name                        = "allow_ssh"
  description                 = "Allow SSH traffic to master"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22-22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 500
  direction                   = "Inbound"
  resource_group_name         = "${azurerm_resource_group.az_kube.name}"
  network_security_group_name = "${azurerm_network_security_group.az_kube.name}"
}

resource "azurerm_network_security_rule" "az_kube_allow_kube_tls" {
  name                        = "allow_kube_tls"
  description                 = "Allow kube-apiserver (tls) traffic to master"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443-6443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 450
  direction                   = "Inbound"
  resource_group_name         = "${azurerm_resource_group.az_kube.name}"
  network_security_group_name = "${azurerm_network_security_group.az_kube.name}"
}

resource "azurerm_virtual_network" "az_kube" {
  name                = "${var.deployid}-vnet"
  address_space       = ["10.0.0.0/8"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.az_kube.name}"
}

# Vertial Machine Subnet
resource "azurerm_subnet" "az_kube_vm" {
  name                      = "${var.deployid}-subnet-vm"
  resource_group_name       = "${azurerm_resource_group.az_kube.name}"
  virtual_network_name      = "${azurerm_virtual_network.az_kube.name}"
  network_security_group_id = "${azurerm_network_security_group.az_kube.id}"
  address_prefix            = "${var.vmCidr}"
}

resource "azurerm_route_table" "az_kube" {
  name                = "${var.deployid}-route-table"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.az_kube.name}"
 # subnets = ["${split(",", join(",", azurerm_subnet.node_bridge.*.id))}"]
}
