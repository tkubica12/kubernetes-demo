- [Helm](#helm)
    - [Install](#install)
    - [When running on AKS, install Helm](#when-running-on-aks-install-helm)
    - [Run Wordpress](#run-wordpress)
    - [Clean up](#clean-up)

# Helm
Helm is package manager for Kubernetes. It allows to put together all resources needed for application to run - deployments, services, statefulsets, variables.

## Install
```
cd ./helm
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.7.2-linux-amd64.tar.gz
tar -zxvf helm-v2.7.2-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin
rm -rf linux-amd64/
```

## When running on AKS, install Helm
```
helm init
```

## Run Wordpress
```
helm 
cd ./helm
helm install --name myblog -f values.yaml .
```

## Clean up
```
helm delete myblog --purge
```

