Kubernetes deployment on Azure with cbr0 bridge network
======
Basic setup with terraform to provision Kubernetes on Azure. These scripts provision a cluster with a master and 3 nodes. 
Also it creates a subnet for each vm than adds a route to route-table. Kubelet will create cbr0 bridge with that associated subnet.
Since kubernetes does not support azure cloud provider, kubelet runs at each node with --pod-cidr=${kubePodCidr}. 
kubePodCidr is the address space of the subnet that we routed. There is only one problem which is terraform does not add subnets to 
route-table (or I could not make it). So this must be handled manually.

## Prerequisites
- Terraform >= v0.7.0-rc2
- Go >= v1.6

## Azure Auth
You're going to need following parameters in order to create cluster:
- subscription_id
- client_id
- client_secret
- tenant_id

You can follow [this](https://www.terraform.io/docs/providers/azurerm/index.html) guide to get them. You must put this variables into "cluster/creds.sh" script.

## Configuration
Edit the file at [cluster/creds.sh](cluster/creds.sh) to your needs.

## Deploy infrastructure

Run the following for provisioning cluster

    ./run apply

If you encounter with error "A retryable error occured. Status=429" restart the script.
After the provision initialize kubectl config with following script

    cd cluster
    ./util init
    
# WARNING
You need to associate each subnet to created route-table, terraform unable to do that I think.



