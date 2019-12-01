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
export version=2.14.2
wget https://get.helm.sh/helm-v$version-linux-amd64.tar.gz
tar -zxvf helm-v$version-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin
rm -rf linux-amd64/
rm -f helm-v$version-linux-amd64.tar.gz
```

## Prepare RBAC rule for Tiller service account
```
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

