- [Service catalog to automatically provision and inject PaaS services from Azure](#service-catalog-to-automatically-provision-and-inject-paas-services-from-azure)
    - [Installing Service Catalog and Azure OSB](#installing-service-catalog-and-azure-osb)
        - [Install Service Catalog CLI](#install-service-catalog-cli)
        - [Install Kubernetes Service Catalog with Helm](#install-kubernetes-service-catalog-with-helm)
        - [Install Open Service Broker for Azure](#install-open-service-broker-for-azure)
    - [Getting started with Service Catalog and Azure services using CLI](#getting-started-with-service-catalog-and-azure-services-using-cli)
    - [Starting application in declarative way](#starting-application-in-declarative-way)
    - [Using Service Catalog and Helm to provision applications](#using-service-catalog-and-helm-to-provision-applications)

# Service catalog to automatically provision and inject PaaS services from Azure

**This section has not yet been updated for AKS**

Kubernetes Service Catalog provides easy to use tooling to provision resources outside of Kubernetes cluster. Especially when running Kubernetes in cloud you might be better served using fully managed platforms for databases, queing or caching rather than building this yourself inside Kubernetes cluster using StatefulSets (you typically gain features such as scaling, patch management, high availability, regional replication, backups, encryption etc.). Service Catalog talks to cloud providers via Open Service Broker standard. We will now explore Service Catalog with Open Service Broker for Azure.

## Installing Service Catalog and Azure OSB
### Install Service Catalog CLI
You can work with Service Catalog using kubectl, but currently that is not very user friendly. Azure team has introduced open source CLI for Service Catalog - in this demo we are going to use it.

```
curl -sLO https://download.svcat.sh/cli/latest/linux/amd64/svcat
chmod +x ./svcat
sudo mv ./svcat /usr/local/bin/
svcat version --client
```

### Install Kubernetes Service Catalog with Helm

```
helm repo add svc-cat https://svc-catalog-charts.storage.googleapis.com
helm install svc-cat/catalog --name catalog \
    --namespace services \
    --set controllerManager.healthcheck.enabled=false
```

### Install Open Service Broker for Azure
Make sure you provide correct IDs for principal etc. so service broker can create resources in Azure.

```
helm repo add azure https://kubernetescharts.blob.core.windows.net/azure
helm install azure/open-service-broker-azure --name azurebroker --namespace services \
  --set azure.subscriptionId=$subscription \
  --set azure.tenantId=$tenant \
  --set azure.clientId=$principal \
  --set azure.clientSecret=$client_secret
```

## Getting started with Service Catalog and Azure services using CLI
First we will investigate Azure services available for consumption via Open Service Broker for Azure. Then we will use imperative method (svcat CLI) to test provisioning of Azure services.

Check Azure broker is visible, initiate sync and after some time list available classes (Azure services)
```
svcat get brokers
svcat get classes
```

Azure services come with different price/performance tiers. This is reflected in Kubernetes Service Catalog as Plans and each plan have a lot of parameters that can be specified such as number of cores, DB size or firewall settings.
```
svcat get plans --class azure-postgresql-9-6
svcat describe plan azure-postgresql-9-6/general-purpose
```

Use CLI to provision service
```
svcat provision myfirstdb --class azure-postgresql-9-6 \
    --plan general-purpose \
    -p location=westeurope \
    -p resourceGroup=aksgroup
svcat get instances
```

Make sure service broker has provisioned resource for us
```
az postgres server list -o table
```

We can now create binding that will also generate Secrets with connection details (those can be used by some application deployment as we will see in following demo). We can provide custom name for binding (--name) and Secret name (--secret), but we will leave this on defaults (the same as instance name).
```
svcat bind myfirstdb
```

All detailes required to connect to service are available in Secret. We can list it via kubectl, but values are base64 encoded (so let's decode it).
```
kubectl get secret myfirstdb -o yaml
printf 'Host: ' && kubectl get secret myfirstdb -o json | jq -r .data.host | base64 --decode && echo && \
printf 'DB: ' && kubectl get secret myfirstdb -o json | jq -r .data.database | base64 --decode && echo && \
printf 'User: ' && kubectl get secret myfirstdb -o json | jq -r .data.username | base64 --decode && echo && \
printf 'Password: ' && kubectl get secret myfirstdb -o json | jq -r .data.password | base64 --decode && echo
```

We can have additional binding to the same service. In this case host and db will be the same, but new login will be created.
```
svcat bind myfirstdb --name myfirstdb2 --secret-name myfirstdb2
printf 'Host: ' && kubectl get secret myfirstdb2 -o json | jq -r .data.host | base64 --decode && echo && \
printf 'DB: ' && kubectl get secret myfirstdb2 -o json | jq -r .data.database | base64 --decode && echo && \
printf 'User: ' && kubectl get secret myfirstdb2 -o json | jq -r .data.username | base64 --decode && echo && \
printf 'Password: ' && kubectl get secret myfirstdb2 -o json | jq -r .data.password | base64 --decode && echo
```

Clean up
```
svcat unbind myfirstdb
svcat deprovision myfirstdb
```

## Starting application in declarative way
In more real situation we will use declarative methods to run our application and let Azure resources be created. We can create Service Catalog Instance and Binding using Kubernetes declarative syntax and then create pod that will get access to service.

```
kubectl apply -f serviceCatalogDemo.yaml
```

Print environmental variables in pod
```
kubectl exec env -- env | grep DB
```

Clean up
```
kubectl delete -f serviceCatalogDemo.yaml
```

## Using Service Catalog and Helm to provision applications
Putting this all together you can create complete Helm application template that will include Azure provisioning part for database, queue or other resources. This might especially useful for CI/CD scenarios.

Azure team has provided modified Helm Charts to demo usage of service broker with applications such as Wordpress.

First ensure we have added Azure repo to our Helm (we did that during instalation of Open Service Broker for Azure).
```
helm repo add azure https://kubernetescharts.blob.core.windows.net/azure
```

Install Wordpress
```
helm install azure/wordpress --name wp --set wordpressUsername=tomas \
    --set wordpressPassword=Azure12345678 \
    --set mysql.azure.location=westeurope 
```

Wait for Helm to complete deployment (helm status wp), get Wordpress instance URL a test.
```
echo http://$(kubectl get svc wp-wordpress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/admin
```

Clean up
```
helm delete wp --purge
```
