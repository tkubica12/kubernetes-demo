# Deploying managed Kubernetes (AKS)
In this section we are going to deploy managed Kubernetes service in Azure. Make sure you have latest version of Azure CLI 2.0 installed. 

**To be refreshed for 1.14**

- [Deploying managed Kubernetes (AKS)](#deploying-managed-kubernetes-aks)
    - [Get credentials](#get-credentials)
    - [Download kubectl](#download-kubectl)
    - [Create VM for testing access within VNET](#create-vm-for-testing-access-within-vnet)
    - [Access GUI](#access-gui)

You can build basic simple cluster as simple as running this command:
```
az aks create -g MyResourceGroup -n MyManagedCluster
```

You can also specify Kubernetes version, VM size or agent count. In our demo we will go after more complex configuration using Advanced Networking, Health monitoring, Azure Active Directory integration and others.

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
az network vnet subnet create -n nodeless-subnet \
        -g $netRg \
        --vnet-name aks-network \
        --address-prefix 192.168.4.0/22
az network vnet subnet create -n testingvm-subnet \
        -g $netRg \
        --vnet-name aks-network \
        --address-prefix 192.168.8.0/24


```

We will integrate cluster with Azure Active Directory authentication. First follow documentation to register with AAD and get details: [https://docs.microsoft.com/en-us/azure/aks/aad-integration](https://docs.microsoft.com/en-us/azure/aks/aad-integration)

Store data in following environmental variables:
```
export aad-server-id=...
export aad-server-key=...
export aad-client-id=...
export aad-tenant-id=
```

If you for some reason do not want to integrate with AAD remove --aad-server-app-id,--aad-server-app-secret, --aad-client-app-id and --aad-tenant-id from az aks create command.

Azure CLI currently do not support creating Log Analytics workspace, so we will do that with portal (or use existing one) and provide workspace id.

Azure CLI will create service principal account for you that is neccessary to deploy AKS. In order to have this under direct control we will use existing service principal account. If you wish CLI to create one for you please remove --service-principal and --client-secret from az aks create command.

In order to use network policy which is currently in preview we need to register this feature and update resource provider.

```
az feature register --name EnableNetworkPolicy --namespace Microsoft.ContainerService
az feature register --name VMSSPreview --namespace Microsoft.ContainerService
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableNetworkPolicy')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}"


az provider register --namespace Microsoft.ContainerService
```

```
export aksRg=aks
export location=westeurope
export subnetId=$(az network vnet subnet show -g $netRg \
                -n aks-subnet \
                --vnet-name aks-network \
                --query id \
                -o tsv	  )
export workspaceId=/subscriptions/YOUR_SUBSCRIPTION_ID/resourcegroups/YOUR_RESOURCE_GROUP/providers/microsoft.operationalinsights/workspaces/YOUR_WORKSPACE_NAME
export principal=YOUT_SERVICE_PRINCIPAL_ID
export client_secret=YOUR_SERVICE_PRINCIPAL_SECRET

az group create -n $aksRg -l $location

az extension add --name aks-preview
az aks create -n aks -g $aksRg\
        --no-ssh-key \
        --kubernetes-version 1.12.6 \
        --node-count 1 \
        --node-vm-size Standard_B2s \
        --network-plugin azure \
        --network-policy azure \
        --vnet-subnet-id $subnetId \
        --docker-bridge-address 172.17.0.1/16 \
        --dns-service-ip 192.168.4.10 \
        --service-cidr 192.168.4.0/22 \
        --max-pods 100 \
        --enable-addons monitoring \
        --workspace-resource-id $workspaceId \
        --service-principal $principal \
        --client-secret $client_secret \
        --aad-server-app-id $aadserverid \
        --aad-server-app-secret $aadserverkey \
        --aad-client-app-id $aadclientid \
        --aad-tenant-id $aadtenantid \
        --enable-vmss
# Autoscaler
#         \
#        --enable-cluster-autoscaler \
#        --min-count 1 \
#        --max-count 3

# Enable Virtual Nodes
az extension add --source https://aksvnodeextension.blob.core.windows.net/aks-virtual-node/aks_virtual_node-0.2.0-py2.py3-none-any.whl

az aks enable-addons \
    --resource-group $aksRg \
    --name aks \
    --addons virtual-node \
    --subnet-name nodeless-subnet
```

### Get credentials
Use Azure CLI to download cluster credentials and merge it to your kubectl configuration file on ~/.kube/config

```
az aks get-credentials -n aks -g $aksRg --admin
```

After merging this cluster becomes your current context. If you have stored multiple clusters you can use following commands to switch between them:

```
kubectl config use-context aks-admin
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
az aks browse -g $aksRg -n aks
```