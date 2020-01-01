- [Helm](#helm)
  - [Install on client machine](#install-on-client-machine)
  - [Deploy Wordpress chart](#deploy-wordpress-chart)
  - [Clean up Wordpress deployment](#clean-up-wordpress-deployment)
  - [Deploy simplistic Helm chart](#deploy-simplistic-helm-chart)
  - [Clean up deployment](#clean-up-deployment)

# Helm
Helm is package manager for Kubernetes. It allows to put together all resources needed for application to run - deployments, services, statefulsets, variables. Helm 2 used server-side component Tiller, but since Helm 3 everything is client-based.

## Install on client machine
```bash
export version=3.0.2
wget https://get.helm.sh/helm-v$version-linux-amd64.tar.gz
tar -zxvf helm-v$version-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin
rm -rf linux-amd64/
rm -f helm-v$version-linux-amd64.tar.gz
```

## Deploy Wordpress chart
We will download package from main Helm repository (stable/wordpress). Note you can add your own repositories (such as Azure Container Registry which can also store Helm charts) or target your local folder. Advantage of Helm is that you can extract parameters and make all Kubernetes YAML files templates. This way you can easily change parameters that are supposed to differ between deployments such as image version (upgrading), URL route (Ingress configuration to distinguish between prod and staging environment) or sizing (less replicas in Dev environment). You can pass all values in YAML file or directly using --set. Note mostly Helm will be used by our CI/CD tool such as Azure DevOps so parameters will live there (eg. in repo and secrets in Azure DevOps variables backed by Azure Key Vault).

```bash
helm upgrade --install myblog stable/wordpress --set persistence.storageclass=default
```

## Clean up Wordpress deployment
```bash
helm delete myblog
```

## Deploy simplistic Helm chart
Look into folder simpleWeb for very basic example. We will use chart.yaml with metadata of our package and in template folder one simple Deployment with image name and image tag as parameters and Service object with no parameters.

```bash
helm upgrade --install myweb ./simpleWeb \
    --set image.name="tkubica/web" \
    --set image.tag="2"
```

## Clean up deployment
```bash
helm delete myweb
```