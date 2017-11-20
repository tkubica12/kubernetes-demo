# Deploying managed Kubernetes (AKS)
This demo is currently build on acs-engine based Kubernetes environment in Azure, nevertheless Microsoft currently offers preview of new managed Kubernetes service (AKS). I plan to rework this demo for AKS in near future.

- [Deploying managed Kubernetes (AKS)](#deploying-managed-kubernetes-aks)
        - [Get credentials](#get-credentials)
        - [Create VM for testing](#create-vm-for-testing)
        - [Access GUI](#access-gui)

After you install latest version of Azure CLI make sure it has access to this new service.
```
az provider register -n Microsoft.ContainerService
az provider show -n Microsoft.ContainerService
```

To setup your managed Kubernetes cluster you can use following commands. Make sure you provide your service-principal and client-secret.

```
az group create -n aks -l westus2
az aks create -n aks -g aks --ssh-key-value "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFhm1FUhzt/9roX7SmT/dI+vkpyQVZp3Oo5HC23YkUVtpmTdHje5oBV0LMLBB1Q5oSNMCWiJpdfD4VxURC31yet4mQxX2DFYz8oEUh0Vpv+9YWwkEhyDy4AVmVKVoISo5rAsl3JLbcOkSqSO8FaEfO5KIIeJXB6yGI3UQOoL1owMR9STEnI2TGPZzvk/BdRE73gJxqqY0joyPSWOMAQ75Xr9ddWHul+v//hKjibFuQF9AFzaEwNbW5HxDsQj8gvdG/5d6mt66SfaY+UWkKldM4vRiZ1w11WlyxRJn5yZNTeOxIYU4WLrDtvlBklCMgB7oF0QfiqahauOEo6m5Di2Ex" --kubernetes-version 1.8.1 --agent-count 2 --admin-username tomas --service-principal $principal --client-secret $client_secret -s Standard_A1
```

### Get credentials

```
az aks get-credentials -n aks -g aks
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