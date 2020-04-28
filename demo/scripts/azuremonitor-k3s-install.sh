#!/bin/sh

# sudo -i

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install app
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade -i my-release bitnami/wordpress

# Install Azure Monitor for Containers
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
helm upgrade -i  azuremonitor incubator/azuremonitor-containers --set omsagent.secret.wsid=$1,omsagent.secret.key=$2,omsagent.env.clusterName=democluster 
