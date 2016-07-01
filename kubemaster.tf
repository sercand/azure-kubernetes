resource "template_file" "kubemaster" {
# count    = "${var.mastercount}"  
  template = "${file("tpl.master.yaml")}"

  vars {
    tenantId                     = "${var.tenantId}"
    subscriptionId               = "${var.subscriptionId}"
    resourceGroup                = "${azurerm_resource_group.az_kube.name}"
    servicePrincipalClientId     = "${var.azureClientId}"
    servicePrincipalClientSecret = "${var.azureClientSecret}"
    caCertificate                = "${base64encode(file("${var.secretPath}/ca.crt"))}"
    apiserverCertificate         = "${base64encode(file("${var.secretPath}/apiserver.crt"))}"
    apiserverPrivateKey          = "${base64encode(file("${var.secretPath}/apiserver.key"))}"
    clientCertificate            = "${base64encode(file("${var.secretPath}/client.crt"))}"
    clientPrivateKey             = "${base64encode(file("${var.secretPath}/client.key"))}"
    sshAuthorizedKey             = "${file(\"${var.secretPath}/${var.username}_rsa.pub\")}"
    k8sVer                       = "${var.k8sVer}"
    hyperkubeImage               = "${var.hyperkubeImage}"
    ETCDEndpoints                = "${var.ETCDEndpoints}"
    masterPrivateIp              = "${var.masterPrivateIP}"
    kubeServiceCidr              = "${var.kubeServiceCidr}"
    kubeClusterCidr              = "${var.kubeClusterCidr}"
    kubeDnsServiceIP             = "${var.kubeDnsServiceIP}"
    kubePodCidr                  = "${azurerm_subnet.master_bridge.address_prefix}"
  }
}

resource "azurerm_public_ip" "masterpublicip" {
  name                         = "${var.deployid}-pip-master"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.az_kube.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.deployid}"
}

resource "azurerm_network_interface" "masternic" {
  name                = "${var.deployid}-nic-master"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.az_kube.name}"
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "masternicipconf"
    subnet_id                     = "${azurerm_subnet.az_kube_vm.id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "${var.masterPrivateIP}"
    public_ip_address_id          = "${azurerm_public_ip.masterpublicip.id}"
  }
}

# Master cbr0 subnet
resource "azurerm_subnet" "master_bridge" {
  #count                     = "${var.nodecount + 1}"
  name                      = "master-subnet"
  resource_group_name       = "${azurerm_resource_group.az_kube.name}"
  virtual_network_name      = "${azurerm_virtual_network.az_kube.name}"
  network_security_group_id = "${azurerm_network_security_group.az_kube.id}"
  address_prefix            = "${var.podIpPrefix}.0.0/24"
  route_table_id            = "${azurerm_route_table.az_kube.id}"
}

resource "azurerm_route" "master_route" {
  name                = "route-master"
  resource_group_name = "${azurerm_resource_group.az_kube.name}"
  route_table_name = "${azurerm_route_table.az_kube.name}"

  address_prefix = "${azurerm_subnet.master_bridge.address_prefix}"
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = "${azurerm_network_interface.masternic.private_ip_address}"
}

resource "azurerm_virtual_machine" "kubemaster" {
  name                  = "${var.deployid}-master"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.az_kube.name}"
  network_interface_ids = ["${azurerm_network_interface.masternic.id}"]
  vm_size               = "${var.mastersize}"

  storage_image_reference {
    publisher = "CoreOS"
    offer     = "CoreOS"
    sku       = "Stable"
    version   = "latest"
  }

  storage_os_disk {
    name          = "vm-master-disk"
    vhd_uri       = "${azurerm_storage_account.az_kube.primary_blob_endpoint}${azurerm_storage_container.az_kube.name}/vm-master-disk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  storage_data_disk {
    name          = "etcd-data-disk"
    vhd_uri       = "${azurerm_storage_account.az_kube.primary_blob_endpoint}${azurerm_storage_container.az_kube.name}/etcd-data-disk.vhd"
    create_option = "empty"
    disk_size_gb  = 10
    lun           = 0
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.username}/.ssh/authorized_keys"
      key_data = "${file(\"${var.secretPath}/${var.username}_rsa.pub\")}"
    }
  }

  os_profile {
    computer_name  = "${var.deployid}-master"
    admin_username = "${var.username}"
    admin_password = "${file(\"${var.secretPath}/admin_password")}"
    custom_data    = "${base64encode(template_file.kubemaster.rendered)}"
  }
}
