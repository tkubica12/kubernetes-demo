# Kubernetes in Azure
This repo contains my Kubernetes demo in Azure.

# Table of Contents
- [Azure Container Instance demo](#azure-container-instance-demo)
    - [Create resource group](#create-resource-group)
    - [Run SQL on Linux container](#run-sql-on-linux-container)
    - [Connect to SQL](#connect-to-sql)
    - [Delete container](#delete-container)
- [Building custom ACS cluster](#building-custom-acs-cluster)
    - [Download ACS engine](#download-acs-engine)
    - [Build cluster and copy kubectl configuratio file](#build-cluster-and-copy-kubectl-configuratio-file)
        - [Mixed cluster with standard ACS networking](#mixed-cluster-with-standard-acs-networking)
        - [Cluster with Azure Networking CNI](#cluster-with-azure-networking-cni)
        - [Cluster with Calico networking policy](#cluster-with-calico-networking-policy)
        - [Create VM for testing](#create-vm-for-testing)
        - [Access GUI](#access-gui)
- [Using stateless app farms in mixed environment](#using-stateless-app-farms-in-mixed-environment)
    - [Deploy multiple pods with Deployment](#deploy-multiple-pods-with-deployment)
    - [Create service to balance traffic internally](#create-service-to-balance-traffic-internally)
    - [Create externally accesable service with Azure LB](#create-externally-accesable-service-with-azure-lb)
    - [Upgrade](#upgrade)
    - [Deploy IIS on Windows pool](#deploy-iis-on-windows-pool)
    - [Test Linux to Windows communication](#test-linux-to-windows-communication)
        - [Connect via internal service endpoint](#connect-via-internal-service-endpoint)
    - [Clean up](#clean-up)
- [Stateful applications and StatefulSet with Persistent Volume](#stateful-applications-and-statefulset-with-persistent-volume)
    - [Check storage class and create Persistent Volume](#check-storage-class-and-create-persistent-volume)
    - [Create StatefulSet with Volume template for Postgresql](#create-statefulset-with-volume-template-for-postgresql)
    - [Connect to PostgreSQL](#connect-to-postgresql)
    - [Destroy Pod and make sure StatefulSet recovers and data are still there](#destroy-pod-and-make-sure-statefulset-recovers-and-data-are-still-there)
    - [Continue in Azure](#continue-in-azure)
    - [Clean up](#clean-up)
- [RBAC with AAD and ACR](#rbac-with-aad-and-acr)
    - [Create namespace with some Pod](#create-namespace-with-some-pod)
    - [Create RBAC credentials and RoleBinding](#create-rbac-credentials-and-rolebinding)
    - [Create configuration context and switch to it](#create-configuration-context-and-switch-to-it)
    - [Test RBAC](#test-rbac)
        - [Make sure user can read Pods](#make-sure-user-can-read-pods)
        - [Make sure user can create Pod](#make-sure-user-can-create-pod)
        - [Check, that user cannot create other objects](#check-that-user-cannot-create-other-objects)
        - [Check, that user cannot delete Pods](#check-that-user-cannot-delete-pods)
        - [Check, that user has no access to different namespaces](#check-that-user-has-no-access-to-different-namespaces)
        - [Switch back to default namespace and clean up](#switch-back-to-default-namespace-and-clean-up)
    - [Custom registry](#custom-registry)
        - [Create Azure Container Registry](#create-azure-container-registry)
        - [Push images to registry](#push-images-to-registry)
        - [Run Kubernetes Pod from Azure Container Registry](#run-kubernetes-pod-from-azure-container-registry)
    - [Clean up](#clean-up)
- [ACI Connector (SuperMario example)](#aci-connector-supermario-example)
    - [Create resource gorup](#create-resource-gorup)
    - [Assign RBAC to default service account](#assign-rbac-to-default-service-account)
    - [Deploy ACI Connector](#deploy-aci-connector)
    - [Deploy pod to ACI](#deploy-pod-to-aci)
    - [Clean up](#clean-up)
- [Networking](#networking)
    - [Azure CNI](#azure-cni)
    - [Network policy with Calico](#network-policy-with-calico)
        - [I will reference my kubectl config pointing to Calico-enabled cluster](#i-will-reference-my-kubectl-config-pointing-to-calico-enabled-cluster)
        - [Create web and db pod](#create-web-and-db-pod)
        - [Make sure web can both ping and mysql to db pod](#make-sure-web-can-both-ping-and-mysql-to-db-pod)
        - [Create network policy to allow mysql communication only](#create-network-policy-to-allow-mysql-communication-only)
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
- [Monitoring](#monitoring)
    - [Prepare Log Analytics / OMS](#prepare-log-analytics-oms)
    - [Deploy agent](#deploy-agent)
    - [Generate message in app](#generate-message-in-app)
    - [Log Analytics](#log-analytics)
    - [Clean up](#clean-up)
- [Author](#author)

# Azure Container Instance demo
Before we start with Kubernetes let see Azure Container Instances. This is top level resource in Azure so you don't have to create (and pay for) any VM, just create container directly and pay by second. In this demo we will deploy Microsoft SQL Server in Linux container.

## Create resource group
```
az group create -n aci-group -l westeurope
```

## Run SQL on Linux container
```
az container create -n mssql -g aci-group --cpu 2 --memory 4 --ip-address public --port 1433 -l eastus --image microsoft/mssql-server-linux -e 'ACCEPT_EULA=Y' 'SA_PASSWORD=my(!)Password' 
export sqlip=$(az container show -n mssql -g aci-group --query ipAddress.ip -o tsv)
watch az container logs -n mssql -g aci-group
```

## Connect to SQL
```
sqlcmd -S $sqlip -U sa -P 'my(!)Password' -Q 'select name from sys.databases'
```

## Delete container
```
az container delete -n mssql -g aci-group -y
az group delete -n aci-group -y
```

# Building custom ACS cluster
Azure Container Instance is deployment, upgrade and scaling tool to get open source orchestrators up and running in Azure quickly. ACS as native embedded Azure offering (in GUI, CLI etc.) is production-grade version of open source acs-engine (deployment tool). In order to get latest features we will download acs-engine so we are able to tweek some of its parameters that are not yet available in version embedded in ACS.

## Download ACS engine
```
wget https://github.com/Azure/acs-engine/releases/download/v0.8.0/acs-engine-v0.8.0-linux-amd64.zip
unzip acs-engine-v0.8.0-linux-amd64.zip
mv acs-engine-v0.8.0-linux-amd64/acs-engine .
```

## Build cluster and copy kubectl configuratio file
We will build multiple clusters to show some additional options, but majority of this demo runs on first one.

### Mixed cluster with standard ACS networking
Our first cluster will be hybrid Linux and Windows agents, with RBAC enabled and with support for Azure Managed Disks as persistent volumes in Kubernetes. Basic networking will be used with integration to Azure Load Balancer (for Kubernetes LodaBalancer Service).

```
./acs-engine generate myKubeACS.json
cd _output/myKubeACS/
az group create -n mykubeacs -l westeurope
az group deployment create --template-file azuredeploy.json --parameters @azuredeploy.parameters.json -g mykubeacs
scp tomas@mykubeacs.westeurope.cloudapp.azure.com:.kube/config ~/.kube/config
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
```
kubectl proxy
```

# Using stateless app farms in mixed environment
This set of demos focus on stateless applications like APIs or web frontend. We will deploy application, balance it internally and externally, do rolling upgrade, deploy both Linux and Windows containers and make sure they can access each other.

## Deploy multiple pods with Deployment
```
kubectl create -f deploymentWeb1.yaml
kubectl get deployments -w
kubectl get pods -o wide
```

## Create service to balance traffic internally
```
kubectl create -f podUbuntu.yaml
kubectl create -f serviceWeb.yaml
kubectl get services
kubectl exec ubuntu -- curl -s myweb-service
```

## Create externally accesable service with Azure LB
```
kubectl create -f serviceWebExt.yaml
```

## Upgrade
```
kubectl apply -f deploymentWeb2.yaml
```

## Deploy IIS on Windows pool
```
kubectl create -f IIS.yaml
kubectl get service
```

## Test Linux to Windows communication
### Connect via internal service endpoint
```
kubectl exec ubuntu -- curl -s myiis-service-ext
```

## Clean up
```
kubectl delete -f serviceWebExt.yaml
kubectl delete -f serviceWeb.yaml
kubectl delete -f podUbuntu.yaml
kubectl delete -f deploymentWeb1.yaml
kubectl delete -f deploymentWeb2.yaml
kubectl delete -f IIS.yaml
```

# Stateful applications and StatefulSet with Persistent Volume
Deployments in Kubernetes are great for stateless applications, but statful apps, eg. databases. might require different handling. For example we want to use persistent storage and make sure, that when pod fails, new is created mapped to the same persistent volume (so data are persisted). Also in stateful applications we want to keep identifiers like network (IP address, DNS) when pod fails and needs to be rescheduled. Also when multiple replicas are used we need to start them one by one, because aften first instance is going to be master and others slave (so we need to wait for first one to come up first). If we need to scale down, we want to do this from last instance (not to scale down by killing first instance which is likely to be master). More details can be found in documentation.

In this demo we will deploy single instance of PostgreSQL.

## Check storage class and create Persistent Volume
```
kubectl get storageclasses
kubectl create -f persistentVolumeClaim.yaml
kubectl get pvc
kubectl get pv
```

Make sure volume is visible in Azure. 

Clean up.
```
kubectl delete -f persistentVolumeClaim.aml
```

## Create StatefulSet with Volume template for Postgresql
```
kubectl create -f statefulSetPVC.yaml
kubectl get pvc -w
kubectl get statefulset -w
kubectl get pods -w
kubectl logs postgresql-0
```

## Connect to PostgreSQL
```
kubectl exec -ti postgresql-0 -- psql -Upostgres
CREATE TABLE mytable (
    name        varchar(50)
);
INSERT INTO mytable(name) VALUES ('Tomas Kubica');
SELECT * FROM mytable;
\q
```

## Destroy Pod and make sure StatefulSet recovers and data are still there
```
kubectl delete pod postgresql-0
kubectl exec -ti postgresql-0 -- psql -Upostgres -c 'SELECT * FROM mytable;'
```

## Periodically backup DB to Azure Blob with CronJob
With containers we should apply to single task per container strategy. Therefore scheduled backup process for our DB should be implemented as separate container. We will use CronJob to schedule regular backups and use environmental variables and secrets to pass information to container. That will contain simple Python script to backup our database and upload to Azure Blob Storage.

### Create storage and container, get credentials
```
az storage account create -n tomasbackupdbstore -g mykubeacs -l westeurope --sku Standard_LRS
export storagekey=$(az storage account keys list -g mykubeacs -n tomasbackupdbstore --query [0].value -o tsv)
az storage container create -n backup --account-name tomasbackupdbstore --account-key $storagekey
```

### Container image for backup job
You can use container image right from Docker Hub, but if you are intersted on how that works please look into backupJob folder. backup.py is simple script that reads inputs from environmental variables (we will pass this to container via Pod definition) and secrets from specific files (we will mount Kubernetes secrets). You can build container with Dockerfile that installs required dependencies such as Python Azure Storage library and pg_dump PostgreSQL backup utility and copies script to image. Here is how you do it:
```
cd ./backupJob
docker.exe build -t tkubica/backupdb .
docker.exe push tkubica/backupdb
```

### Prepare secrets
We will pass non-sensitive information to our container via environmental variables. Nevertheless two items are considered sensitive - storage key and DB password. Therefore we will rather use concept of Kubernetes secret to pass this to container in more secured way. We need to create files with secrets and then create secret. This object is than mapped to Pod as volume.

```
echo -n 'Azure12345678' > dbPassword.txt
echo -n $storagekey > storageKey.txt
kubectl create secret generic backupcredentials --from-file=./dbPassword.txt --from-file=./storageKey.txt
rm dbPassword.txt
rm storageKey.txt
```

### Use CronJob to schedule backup job
Read throw cronJobBackup.yaml. We are (for demonstration purposes) scheduling backup to run every minute and provide Pod template. In that we use env to pass information about DB host, username etc. and also mount volume with secrets.

```
kubectl create -f cronJobBackup.yaml
kubectl get pods -w
az storage blob list --account-name tomasbackupdbstore --account-key $storagekey -c backup
```

### Clean up
```
kubectl delete -f cronJobBackup.yaml
kubectl delete secret backupcredentials
az storage account delete -n tomasbackupdbstore -g mykubeacs -y
```

## Continue in Azure
Destroy statefulset and pvc, keep pv
```
kubectl delete -f statefulSetPVC.yaml
```

Go to GUI and map IaaS Volume to VM, then mount it and show content.
```
ssh tomas@mykubeextvm.westeurope.cloudapp.azure.com
ls /dev/sd*
sudo mkdir /data
sudo mount /dev/sdc /data
sudo ls -lh /data/pgdata/
sudo umount /dev/sdc
```

Detach in GUI

## Clean up
```
kubectl delete pvc postgresql-volume-claim-postgresql-0

```

# RBAC with AAD and ACR
When using Kubernetes in enterprise there might be need to role based access control and strong authentication. In this demo we will see how to to use namespaces in Kubernetes to isolate resources from control plane level, how to authenticate user with strong Azure Active Directory authentication and how to authorize what each user can do with Kubernetes RBAC. Also we will look into private registry, how to secure it and make sure company provided images are used.

## Create namespace with some Pod
```
kubectl create namespace rbac
kubectl create -f podUbuntu.yaml --namespace rbac
kubectl get pods
kubectl get pods --namespace rbac
```

## Create RBAC credentials and RoleBinding
Provide correct credentials like client-id, tenant-id etc. Also in roleBindingUser1.yaml make sure you replace first UUID with your directory-id (AAD domain id) and after # use id of user being used (in my case id of user1@tomsakubica.cz).
```
. rbacConfig
kubectl config set-credentials "user1@tomaskubica.cz" --auth-provider=azure --auth-provider-arg=environment=AzurePublicCloud --auth-provider-arg=client-id=$clientid --auth-provider-arg=tenant-id=$tenantid --auth-provider-arg=apiserver-id=$apiserverid 

kubectl create -f myrole.yaml
kubectl create -f roleBindingUser1.yaml
```

## Create configuration context and switch to it

```
kubectl config set-context rbac --namespace rbac --cluster mykubeacs --user user1@tomaskubica.cz
kubectl config use-context rbac
```

## Test RBAC
### Make sure user can read Pods
```
kubectl get pods
```

### Make sure user can create Pod
```
kubectl create -f podNetWeb.yaml
```

### Check, that user cannot create other objects
```
kubectl create -f serviceWeb.yaml
```

### Check, that user cannot delete Pods
```
 kubectl delete pod ubuntu
```

### Check, that user has no access to different namespaces
```
kubectl get pods --namespace default
```

### Switch back to default namespace and clean up
```
kubectl config use-context mykubeacs
kubectl delete namespace rbac
```

## Custom registry
### Create Azure Container Registry
```
az group create -n mykuberegistry -l westeurope
az acr create -g mykuberegistry -n tomascontainers --sku Managed_Standard --admin-enabled true
az acr credential show -n tomascontainers -g mykuberegistry
export acrpass=$(az acr credential show -n tomascontainers -g mykuberegistry --query [passwords][0][0].value -o tsv)
```

### Push images to registry
```
docker.exe images
docker.exe tag tkubica/web:1 tomascontainers.azurecr.io/web:1
docker.exe tag tkubica/web:2 tomascontainers.azurecr.io/web:2
docker.exe tag tkubica/web:1 tomascontainers.azurecr.io/private/web:1
docker.exe login -u tomascontainers -p $acrpass tomascontainers.azurecr.io
docker.exe push tomascontainers.azurecr.io/web:1
docker.exe push tomascontainers.azurecr.io/web:2
docker.exe push tomascontainers.azurecr.io/private/web:1
az acr repository list -n tomascontainers -o table
```

### Run Kubernetes Pod from Azure Container Registry
```
kubectl create -f podACR.yaml
```

## Clean up
```
kubectl delete -f clusterRoleBindingUser1.yaml
az group delete -n mykuberegistry -y --no-wait
docker.exe rmi tomascontainers.azurecr.io/web:1
docker.exe rmi tomascontainers.azurecr.io/web:2
docker.exe rmi tomascontainers.azurecr.io/private/web:1

```

# ACI Connector (SuperMario example)
As show in first example Azure Container Instance (in preview) can be used as top level resources. Azure can run containers directly without need to do so in VMs. There is experimental connector available so that Azure behaves like Kubernetes node with infinite capacity. In this demo we will install this connector and schedule pod to run on this infinite node reprezentaion of Azure.

## Create resource gorup
```
az group create -n aci-connect -l eastus
```

## Assign RBAC to default service account
```
kubectl create -f clusterRoleBindingService.yaml
```

## Deploy ACI Connector
```
kubectl create -f aciConnector.yaml
kubectl get nodes
```

## Deploy pod to ACI
```
kubectl create -f podACI.yaml
kubectl get pods -o wide
az container list -g aci-connect -o table
```
Connect to IP on port 8080

## Clean up
```
kubectl delete -f podACI.yaml
kubectl delete -f aciConnector.yaml
kubectl delete -f clusterRoleBindingService.yaml
```

# Networking
We have seen a lot of networking already: internal ballancing and service discovery, external balancing with automatic integration to Azure Load Balancer with public IP, communication between pods in container etc. In this section we will focus on some other aspects namely networking policy.

## Azure CNI
In Azure CNI cluster demonstrate how containers take IP addresses directly from VNET. Access pod directly from VM deployed in the same VNET.

## Network policy with Calico
Calico is plugin that implements Kubernetes network policy, namely microsegmentation (L4 filtering between pods). In this demo we will create Web and DB and provide strict policy what and how can communicate.

### I will reference my kubectl config pointing to Calico-enabled cluster
```
. calico.rc
```

### Create web and db pod
```
kubectl create -f podNetWeb.yaml
kubectl create -f podNetDB.yaml
kubectl exec net-web ip a
kubectl exec net-db ip a
```

### Make sure web can both ping and mysql to db pod
```
export dbip=$(kubectl get pod net-db -o json | jq -r '.status.podIP')
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```

### Create network policy to allow mysql communication only
```
kubectl create -f networkPolicy.yaml
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```

# Helm
Helm is package manager for Kubernetes. It allows to put together all resources needed for application to run - deployments, services, statefulsets, variables.

## Install
```
cd ./helm
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.6.1-linux-amd64.tar.gz
tar -zxvf helm-v2.6.1-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin
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

# Monitoring
## Prepare Log Analytics / OMS
Create Log Analytics account and gather workspace ID and key.
Create Container Monitoring Solution.

## Deploy agent
Modify daemonSetOMS.yaml with your workspace ID and key.

```
kubectl create -f daemonSetOMS.yaml
```

## Generate message in app
```
kubectl create -f podUbuntu.yaml
kubectl exec -ti ubuntu -- logger My app has just logged something

```
## Log Analytics
Container performance example
```
Perf
 | where ObjectName == "Container" and CounterName == "Disk Reads MB"
 | summarize sum(CounterValue) by InstanceName, bin(TimeGenerated, 5m)
 | render timechart 
```

## Clean up
```
kubectl delete -f podUbuntu.yaml
kubectl delete -f daemonSetOMS.yaml
```

# Author
Tomas Kubica, linkedin.com/in/tkubica, Twittter: @tkubica

Blog in Czech: https://tomaskubica.cz

Looking forward for your feedback and suggestions!