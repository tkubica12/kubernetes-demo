#!/bin/sh
echo Usage: position arguments
echo        -> service principal id
echo        -> service principal secret
echo        -> tenant id
echo        -> log workspace secret
echo        -> log workspace id
echo        -> log workspace resource id
echo        -> resource group name
echo

# sudo -i

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Azure CLI
apt-get update
apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list
apt-get update
apt-get install -y azure-cli

# Install CLI Arc for Kubernetes extensions
az extension add --name connectedk8s
az extension add --name k8sconfiguration

# Login to Azure using managed identity
az login --service-principal -u $1 -p $2 --tenant $3

# Onboard cluster to Arc
az connectedk8s connect --name tomas-k3s --resource-group $7 --tags logAnalyticsWorkspaceResourceId=$6 --location westeurope
export clusterId=$(az connectedk8s show --name tomas-k3s --resource-group $7 --query id -o tsv)

# Install Azure Monitor for Containers
curl -o enable-monitoring.sh -L https://aka.ms/enable-monitoring-bash-script
bash enable-monitoring.sh --resource-id $clusterId --client-id $1 --client-secret $2  --tenant-id $3 --workspace-id $4 #--kube-context $kubeContext 

# Install Azure Policy
helm repo add azure-policy https://raw.githubusercontent.com/Azure/azure-policy/master/extensions/policy-addon-kubernetes/helm-charts
helm repo update
helm upgrade -i azure-policy-addon azure-policy/azure-policy-addon-arc-clusters \
    --set azurepolicy.env.resourceid=$clusterId  \
    --set azurepolicy.env.clientid=$1 \
    --set azurepolicy.env.clientsecret=$2 \
    --set azurepolicy.env.tenantid=$3

