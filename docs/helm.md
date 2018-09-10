- [Helm](#helm)
    - [Install on client machine](#install-on-client-machine)
    - [Prepare RBAC rule for Tiller service account](#prepare-rbac-rule-for-tiller-service-account)
    - [Install Helm server component](#install-helm-server-component)
    - [Run Wordpress](#run-wordpress)
    - [Clean up](#clean-up)

# Helm
Helm is package manager for Kubernetes. It allows to put together all resources needed for application to run - deployments, services, statefulsets, variables.

## Install on client machine
```
cd ./helm
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar -zxvf helm-v2.9.1-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin
rm -rf linux-amd64/
```

## Prepare RBAC rule for Tiller service account
```
cd ../kuberesources
kubectl apply -f tiller-rbac.yaml
```

## Install Helm server component
```
helm init --service-account tiller
```

## Run Wordpress
```
helm install --name myblog stable/wordpress --set persistence.storageclass=default
```

## Clean up
```
helm delete myblog --purge
```

