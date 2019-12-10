- [KEDA - Kubernetes-based Event Driven Autoscaling](#keda---kubernetes-based-event-driven-autoscaling)
  - [Install Azure Functions Tools on Ubuntu 18.04](#install-azure-functions-tools-on-ubuntu-1804)
  - [Install KEDA](#install-keda)
  - [Prepare Azure Container Registry](#prepare-azure-container-registry)
  - [Creating Function to consume messages from Storage Queue](#creating-function-to-consume-messages-from-storage-queue)
  - [Creating Function to react on HTTP request](#creating-function-to-react-on-http-request)
  - [Cleanup](#cleanup)

# KEDA - Kubernetes-based Event Driven Autoscaling
KEDA is autoscaling component for Kubernetes with scale-to-zero functionality and ability to bring metrics from various components such as Azure Service Bus and others.

## Install Azure Functions Tools on Ubuntu 18.04
```bash
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azure-functions-core-tools
```

## Install KEDA
```bash
func kubernetes install --namespace keda
```

## Prepare Azure Container Registry
```bash
export resourceGroup=akstemp
export acr=tomaskedaregistry123

az acr create -n $acr -g $resourceGroup --sku Basic
az acr login -n $acr -g $resourceGroup
```

## Creating Function to consume messages from Storage Queue
In this demo we will create Azure Function to react on new message in Storage Queue.

```bash
mkdir ~/keda-worker
cd ~/keda-worker

func init . --docker --worker-runtime node --language javascript

func new -t "Azure Queue Storage trigger" -n QueueTrigger
```

Create Azure Storage Account

```bash
export storageName=myuniquekedastorage
export resourceGroup=akstemp
az storage account create --sku Standard_LRS -g $resourceGroup -n $storageName
export connectionString=$(az storage account show-connection-string --n $storageName --query connectionString -o tsv)
az storage queue create -n myqueue --connection-string $connectionString
```

We will replace local.settings.json with storage connection string configuration.

```bash
cat > local.settings.json << EOF
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "AzureWebJobsStorage": "$connectionString"
  }
}
EOF
```

Add connection string reference and queue name to function.json.

```bash
cat > QueueTrigger/function.json << EOF
{
  "bindings": [
    {
      "name": "myQueueItem",
      "type": "queueTrigger",
      "direction": "in",
      "queueName": "myqueue",
      "connection": "AzureWebJobsStorage"
    }
  ]
}
EOF
```

Deploy Function to AKS.

```bash
func kubernetes deploy --name keda-worker \
    --registry $acr".azurecr.io" \
    --max-replicas 10 \
    --cooldown-period 30
```

Monotir running Pods. After 30 seconds there will be no worker. Use Azure Portal (Storage Explorer) to create message in queue and see KEDA scaling up.

```bash
kubectl get pods -w
```

## Creating Function to react on HTTP request
In this demo we will create Azure Function to reast on HTTP request.

```bash
mkdir ~/keda-webapi
cd ~/keda-webapi

func init . --docker --worker-runtime node --language javascript

func new -t "HTTP trigger" -n HttpTrigger

func kubernetes deploy --name keda-webapi \
    --registry $acr".azurecr.io" \
    --max-replicas 10 
```

Get Service public IP address and try to access it via browser.

```bash
kubectl get service
```

Wait for 5 minutes. With no access to our API, KEDA will remove running Pod. After that open browser again and see how Pod is comming up in reaction to request.

```bash
kubectl get pods -w
```

## Cleanup
rm -rf ~/keda-webapi
rm -rf ~/keda-worker
kubectl delete deploy keda-webapi-http
kubectl delete deploy keda-worker
kubectl delete service keda-webapi-http
kubectl delete deploy keda-worker
kubectl delete secret keda-worker
kubectl delete scaledobject keda-worker
func kubernetes remove --namespace keda
