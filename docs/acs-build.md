# Building custom ACS cluster
Azure Container Instance is deployment, upgrade and scaling tool to get open source orchestrators up and running in Azure quickly. ACS as native embedded Azure offering (in GUI, CLI etc.) is production-grade version of open source acs-engine (deployment tool). In order to get latest features we will download acs-engine so we are able to tweek some of its parameters that are not yet available in version embedded in ACS.

- [Building custom ACS cluster](#building-custom-acs-cluster)
    - [Download ACS engine](#download-acs-engine)
    - [Build cluster and copy kubectl configuratio file](#build-cluster-and-copy-kubectl-configuratio-file)
        - [Mixed cluster with standard ACS networking](#mixed-cluster-with-standard-acs-networking)
        - [Cluster with Azure Networking CNI](#cluster-with-azure-networking-cni)
        - [Cluster with Calico networking policy](#cluster-with-calico-networking-policy)
        - [Create VM for testing](#create-vm-for-testing)
        - [Access GUI](#access-gui)

## Download ACS engine
```
wget https://github.com/Azure/acs-engine/releases/download/v0.9.3/acs-engine-v0.9.3-linux-amd64.zip
unzip acs-engine-v0.9.3-linux-amd64.zip
mv acs-engine-v0.9.3-linux-amd64/acs-engine .
rm -rf acs-engine-v0.9.3-linux-amd64*
```

## Build cluster and copy kubectl configuratio file
We will build multiple clusters to show some additional options, but majority of this demo runs on first one.

### Mixed cluster with standard ACS networking
Our first cluster will be hybrid Linux and Windows agents, with RBAC enabled and with support for Azure Managed Disks as persistent volumes in Kubernetes. Basic networking will be used with integration to Azure Load Balancer (for Kubernetes LodaBalancer Service).

```
./acs-engine generate acs.json
cd _output/acstomas/
az group create -n acs -l westeurope
az group deployment create --template-file azuredeploy.json --parameters @azuredeploy.parameters.json -g acs
scp tomas@acstomas.westeurope.cloudapp.azure.com:.kube/config ~/.kube/config-acs
```

### Cluster with Azure Networking CNI
In this cluster we will use Azure Networkin CNI plugin. This allows pods to use directly IP addresses from Azure VNET and allows for Azure Networking features to be used with pods - for example Network Security Groups or direct communication between pods in cluster and VMs in the same VNET.

```
./acs-engine generate myKubeAzureNet.json
cd _output/myKubeAzureNet/
az group create -n mykubeazurenet -l westeurope
az group deployment create --template-file azuredeploy.json --parameters @azuredeploy.parameters.json -g mykubeazurenet
scp tomas@mykubeazurenet.westeurope.cloudapp.azure.com:.kube/config ~/.kube/config-azurenet
```

### Cluster with Calico networking policy
In this cluster we deploy Calico to implement networking policy. This is Kubernetes option to handle microsegmentation - L4 firewalling between pods.

```
./acs-engine generate myKubeCalico.json 
cd _output/myKubeCalico/
az group create -n mykubecalico -l westeurope
az group deployment create --template-file azuredeploy.json --parameters @azuredeploy.parameters.json -g mykubecalico
scp tomas@mykubecalico.westeurope.cloudapp.azure.com:.kube/config ~/.kube/config-calico
```

### Create VM for testing
```
export vnet=$(az network vnet list -g mykubeacs --query [].name -o tsv)

az vm create -n myvm -g mykubeacs --admin-username tomas --ssh-key-value "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFhm1FUhzt/9roX7SmT/dI+vkpyQVZp3Oo5HC23YkUVtpmTdHje5oBV0LMLBB1Q5oSNMCWiJpdfD4VxURC31yet4mQxX2DFYz8oEUh0Vpv+9YWwkEhyDy4AVmVKVoISo5rAsl3JLbcOkSqSO8FaEfO5KIIeJXB6yGI3UQOoL1owMR9STEnI2TGPZzvk/BdRE73gJxqqY0joyPSWOMAQ75Xr9ddWHul+v//hKjibFuQF9AFzaEwNbW5HxDsQj8gvdG/5d6mt66SfaY+UWkKldM4vRiZ1w11WlyxRJn5yZNTeOxIYU4WLrDtvlBklCMgB7oF0QfiqahauOEo6m5Di2Ex" --image UbuntuLTS --nsg "" --vnet-name $vnet --subnet k8s-subnet --public-ip-address-dns-name mykubeextvm --size Basic_A0

ssh tomas@mykubeextvm.westeurope.cloudapp.azure.com
```

### Access GUI
Create proxy tunnel and open GUI on 127.0.0.1:8001/ui

```
kubectl proxy
```