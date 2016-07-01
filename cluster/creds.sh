#!/bin/bash
export ARM_SUBSCRIPTION_ID=""
export ARM_CLIENT_ID=""
export ARM_CLIENT_SECRET=""
export ARM_TENANT_ID=""

export AZURE_LOCATION="northeurope"
export AZURE_DEPLOY_ID="kubeazure2"
export MASTER_FQDN=$AZURE_DEPLOY_ID.$AZURE_LOCATION.cloudapp.azure.com
export CLUSTER_DOMAIN=example.com
export MASTER_PRIVATE_IP="10.128.1.4"
export ADMIN_USER_NAME="kubeazure"

export MASTER_SIZE="Standard_D1_v2"
export NODE_SIZE="Standard_D1_v2"

export TF_VAR_nodecount=3

export TF_VAR_k8sVer="v1.2.4"
export TF_VAR_hyperkubeImage="gcr.io/google_containers/hyperkube-amd64:v1.2.4"
export TF_VAR_podIpPrefix="10.244"
export TF_VAR_kubeClusterCidr="${TF_VAR_podIpPrefix}.0.0/16"
export TF_VAR_ETCDEndpoints="http://${MASTER_PRIVATE_IP}:2379"
export TF_VAR_vmCidr="10.128.0.0/16"
