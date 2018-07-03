# Deploying managed Kubernetes (AKS)
In this section we are going to deploy managed Kubernetes service in Azure. Make sure you have latest version of Azure CLI 2.0 installed. 

- [Deploying managed Kubernetes (AKS)](#deploying-managed-kubernetes-aks)
                - [Get credentials](#get-credentials)
                - [Download kubectl](#download-kubectl)
                - [Create VM for testing access within VNET](#create-vm-for-testing-access-within-vnet)
                - [Access GUI](#access-gui)

In this demo we will use Advanced Networking.

First create virtual network and subnets.

```
export netRg=aksnetwork
export location=westeurope
az group create -n $netRg -l $location
az network vnet create -g $netRg \
	-n aks-network \
	--address-prefix 192.168.0.0/20 \
	--subnet-name aks-subnet \
	--subnet-prefix 192.168.0.0/22
az network vnet subnet create -n testingvm-subnet \
        -g $netRg \
        --vnet-name aks-network \
        --address-prefix 192.168.8.0/24

```

Deploy Kubernetes cluster with advanced networking, HTTP application routing and monitoring solution.

Azure CLI currently do not support creating Log Analytics workspace, so we will do that with portal (or use existing one) and provide workspace id.

Azure CLI will create service principal account for you that is neccessary to deploy AKS. In order to have this under direct control we will use existing service principal account. If you wish CLI to create one for you please remove --service-principal and --client-secret from az aks create command.

```
export aksRg=aksgroup
export location=westeurope
export subnetId=$(
                az network vnet subnet show -g $netRg \
                -n aks-subnet \
                --vnet-name aks-network \
                --query id \
                -o tsv	  )
export workspaceId=/subscriptions/YOUR_SUBSCRIPTION_ID/resourcegroups/YOUR_RESOURCE_GROUP/providers/microsoft.operationalinsights/workspaces/YOUR_WORKSPACE_NAME
export principal=YOUT_SERVICE_PRINCIPAL_ID
export client_secret=YOUR_SERVICE_PRINCIPAL_SECRET

az group create -n $aksRg -l $location

az aks create -n akscluster -g $aksRg \
        --no-ssh-key \
        --kubernetes-version 1.10.3 \
        --node-count 3 \
        --node-vm-size Standard_B2s \
        --network-plugin azure \
        --vnet-subnet-id $subnetId \
        --docker-bridge-address 172.17.0.1/16 \
        --dns-service-ip 192.168.4.10 \
        --service-cidr 192.168.4.0/22 \
        --enable-addons http_application_routing,monitoring \
        --workspace-resource-id $workspaceId \
        --enable-rbac \
        --service-principal $principal \
        --client-secret $client_secret
```

### Get credentials
Use Azure CLI to download cluster credentials and merge it to your kubectl configuration file on ~/.kubce/config

```
az aks get-credentials -n akscluster -g $aksRg
```

### Download kubectl

```
sudo az aks install-cli
```

### Create VM for testing access within VNET
```
export vmSubnetId=$(
                az network vnet subnet show -g $netRg \
                -n testingvm-subnet \
                --vnet-name aks-network \
                --query id \
                -o tsv	  )
export testingvmResourceGroup=akstestingvm
export location=westeurope

az group create -n $testingvmResourceGroup -l $location
az vm create -n mytestingvm \
        -g $testingvmResourceGroup \
        --admin-username tomas \
        --admin-password Azure12345678 \
        --authentication-type password \
        --image UbuntuLTS \
        --nsg "" \
        --subnet $vmSubnetId \
        --size Standard_B1s

export vmIp=$(az network public-ip show -n mytestingvmPublicIP -g akstestingvm --query ipAddress -o tsv)
ssh tomas@$vmIp
```

### Access GUI
Create proxy tunnel and open GUI on 127.0.0.1:8001/ui

```
az aks browse -g $aksRg -n akscluster
```