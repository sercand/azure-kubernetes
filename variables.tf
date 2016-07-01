variable "location" {
  type    = "string"
  default = "northeurope"
}

variable "mastersize" {
  type    = "string"
  default = "Standard_D1_v2"
}

variable "nodesize" {
  type    = "string"
  default = "Standard_D1_v2"
}

variable "nodecount" {
  type    = "string"
  default = "0"
}

variable "deployid" {
  type    = "string"
  default = "azurekube"
}

variable "masterPrivateIP" {
  type    = "string"
  default = "10.0.1.4"
}


variable "username" {
  type    = "string"
  default = "azurekube"
}

variable "hyperkubeImage" {
  type    = "string"
  default = "gcr.io/google_containers/hyperkube-amd64:v1.2.4"
}

variable "k8sVer" {
  type    = "string"
  default = "v1.2.4"
}

variable "kubeClusterCidr" {
  type    = "string"
  default = "10.244.0.0/16"
}

variable "podIpPrefix" {
  type    = "string"
  default = "10.244"
}

variable "kubeServiceCidr" {
  type    = "string"
  default = "10.3.0.0/16"
}

variable "kubeDnsServiceIP" {
  type    = "string"
  default = "10.3.0.10"
}

variable "vmCidr" {
  type = "string"
  default = "10.128.0.0/16"
}

variable "ETCDEndpoints" {
  type    = "string"
  default = "http://10.0.1.4:2379"
}

variable "secretPath" {
  type    = "string"
  default = "secret"
}

#Azure variables
variable "tenantId" {
  type = "string"
}

variable "subscriptionId" {
  type = "string"
}

variable "azureClientId" {
  type = "string"
}

variable "azureClientSecret" {
  type = "string"
}

