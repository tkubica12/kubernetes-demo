- [Helm](#helm)
    - [Install](#install)
    - [Run Wordpress](#run-wordpress)
    - [Clean up](#clean-up)
- [CI/CD with Jenkins and Helm](#cicd-with-jenkins-and-helm)
    - [Install Jenkins to cluster via Helm](#install-jenkins-to-cluster-via-helm)
    - [Configure Jenkins and its pipeline](#configure-jenkins-and-its-pipeline)
    - [Run "build"](#run-build)
- [Draft](#draft)
    - [Install Traefik and create DNS entry](#install-traefik-and-create-dns-entry)
    - [Install Draft](#install-draft)
    - [Run](#run)

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

# CI/CD with Jenkins and Helm
In this demo we will see Jenkins deployed into Kubernetes via Helm and have Jenkins Agents spin up automatically as Pods.

CURRENT ISSUE: at the moment NodeSelector for agent does not seem to be delivered to Kubernetes cluster correctly. Since our cluster is hybrid (Linux and Windows) in order to work around it now we need to turn of Windows nodes.

## Install Jenkins to cluster via Helm
```
helm install --name jenkins stable/jenkins -f jenkins-values.yaml
```

## Configure Jenkins and its pipeline
Use this as pipeline definition
```
podTemplate(label: 'mypod') {
    node('mypod') {
        stage('Do something nice') {
            sh 'echo something nice'
        }
    }
}

```

## Run "build"
Build project in Jenkins and watch containers to spin up and down.
```
kubectl get pods -o wide -w
```


# Draft
## Install Traefik and create DNS entry
```
helm fetch --untar stable/traefik
```
Modify deployment template to deploy to linuxpool:
```
      nodeSelector:
        agentpool: linuxpool
```
```
cd traefik
helm install . --name ingress
kubectl get service ingress-traefik
export draftip=$(kubectl get service ingress-traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export oldip=$(az network dns record-set a show -n *.draft -g shared-services -z azure.tomaskubica.cz --query arecords[0].ipv4Address -o tsv)
az network dns record-set a remove-record -a $oldip -n *.draft -g shared-services -z azure.tomaskubica.cz
az network dns record-set a add-record -n *.draft -a $draftip -g shared-services -z azure.tomaskubica.cz
```

## Install Draft
```
wget https://github.com/Azure/draft/releases/download/v0.7.0/draft-v0.7.0-linux-amd64.tar.gz
tar -xvf draft-v0.7.0-linux-amd64.tar.gz
sudo mv linux-amd64/draft /usr/bin/

cd nodeapp
draft create
```

## Run
```
cd nodeapp
draft up
draft connect
```