resource "template_file" "kubenode" {
  count    = "${var.nodecount}"  
  template = "${file("tpl.node.yaml")}"

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
    kubePodCidr                  = "${element(azurerm_subnet.node_bridge.*.address_prefix, count.index)}"
  }
}

resource "azurerm_network_interface" "nodenic" {
  count                = "${var.nodecount}"
  name                 = "${var.deployid}-nic-node-${count.index}"
  location             = "${var.location}"
  resource_group_name  = "${azurerm_resource_group.az_kube.name}"
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "nodenicip${count.index}"
    subnet_id                     = "${azurerm_subnet.az_kube_vm.id}"
    private_ip_address_allocation = "dynamic"
  }
}

# Node VM cbr0 subnet
resource "azurerm_subnet" "node_bridge" {
  count                     = "${var.nodecount}"
  name                      = "node-subnet-${count.index}"
  resource_group_name       = "${azurerm_resource_group.az_kube.name}"
  virtual_network_name      = "${azurerm_virtual_network.az_kube.name}"
  network_security_group_id = "${azurerm_network_security_group.az_kube.id}"
  address_prefix            = "${var.podIpPrefix}.${count.index + 10}.0/24"
  route_table_id            = "${azurerm_route_table.az_kube.id}"
}

resource "azurerm_route" "node_route" {
  count               = "${var.nodecount}"
  name                = "route-node-${count.index}"
  resource_group_name = "${azurerm_resource_group.az_kube.name}"
  route_table_name = "${azurerm_route_table.az_kube.name}"

  address_prefix = "${element(azurerm_subnet.node_bridge.*.address_prefix, count.index)}"
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = "${element(azurerm_network_interface.nodenic.*.private_ip_address, count.index)}"
}

resource "azurerm_virtual_machine" "kubenode" {
  count                 = "${var.nodecount}"
  name                  = "${var.deployid}-node-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.az_kube.name}"
  network_interface_ids = ["${element(azurerm_network_interface.nodenic.*.id, count.index)}"]
  vm_size               = "${var.nodesize}"

  storage_image_reference {
    publisher = "CoreOS"
    offer     = "CoreOS"
    sku       = "Stable"
    version   = "latest"
  }

  storage_os_disk {
    name          = "vm-node-disk"
    vhd_uri       = "${azurerm_storage_account.az_kube.primary_blob_endpoint}${azurerm_storage_container.az_kube.name}/vm-node-disk-${count.index}.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.username}/.ssh/authorized_keys"
      key_data = "${file(\"${var.secretPath}/${var.username}_rsa.pub\")}"
    }
  }

  os_profile {
    computer_name  = "${var.deployid}-node-${count.index}"
    admin_username = "${var.username}"
    admin_password = "${file(\"${var.secretPath}/admin_password")}"
    custom_data    = "${base64encode(element(template_file.kubenode.*.rendered, count.index))}"
  }
}
