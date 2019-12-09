# Install DAPR CLI
First install DAPR CLI

```
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
```

# Install DAPR in AKS
From DAPR CLI deploy solution to AKS

```
dapr init --kubernetes 
```

# Prepare external components
First we will prepare external PaaS components to be used as backend for DAPR services.

```
export resourceGroup=akstemp
```

## Provision CosmosDB account, database and container
```
export cosmosdbAccount=mujdaprcosmosdb
az cosmosdb create -n $cosmosdbAccount -g $resourceGroup
az cosmosdb sql database create -a $cosmosdbAccount -n daprdb -g $resourceGroup
az cosmosdb sql container create -g $resourceGroup -a $cosmosdbAccount -d daprdb -n statecont -p "/id"
```

## Provision Azure Service Bus
```
export servicebus=mujdaprservicebus
az servicebus namespace create -n $servicebus -g $resourceGroup
az servicebus topic create -n orders --namespace-name $servicebus -g $resourceGroup
az servicebus namespace authorization-rule create --namespace-name $servicebus \
  -g $resourceGroup \
  --name daprauth \
  --rights Send Listen Manage
```

## Provision blob storage
```
export storageaccount=mujdaprstorageaccount
az storage account create -n $storageaccount -g $resourceGroup --sku Standard_LRS --kind StorageV2
export storageConnection=$(az storage account show-connection-string -n $storageaccount -g $resourceGroup --query connectionString -o tsv)
az storage container create -n daprcontainer --connection-string $storageConnection
```

## Privision Event Hub
```
export eventhub=mujdapreventhub
az eventhubs namespace create -g $resourceGroup -n $eventhub --sku Basic
az eventhubs eventhub create -g $resourceGroup --namespace-name $eventhub -n dapreventhub --message-retention 1
az eventhubs eventhub authorization-rule create \
  -g $resourceGroup \
  --namespace-name $eventhub \
  --eventhub-name dapreventhub \
  -n daprauth \
  --rights Listen Send
```

# Provision DAPR components
DAPR uses custom resource Component to configure backend implementation for its various services. In order to easily pass connection strings and other details without manually modifying YAMLs we will use Helm 3 to install it. Please note we are not following best practices here - secret values should be passed via Secret object, but we are not doing that for simplicity reasons.

```
cd dapr
helm upgrade dapr-components ./dapr-components --install \
  --set cosmosdb.url=$(az cosmosdb show -n $cosmosdbAccount -g $resourceGroup --query documentEndpoint -o tsv) \
  --set cosmosdb.masterKey=$(az cosmosdb keys list -n $cosmosdbAccount -g $resourceGroup --type keys --query primaryMasterKey -o tsv) \
  --set cosmosdb.database=daprdb \
  --set cosmosdb.collection=statecont \
  --set serviceBus.connectionString=$(az servicebus namespace authorization-rule keys list --namespace-name $servicebus -g $resourceGroup --name daprauth --query primaryConnectionString -o tsv) \
  --set blob.storageAccount=$storageaccount \
  --set blob.key=$(az storage account keys list -n $storageaccount -g $resourceGroup --query [0].value -o tsv) \
  --set blob.container=daprcontainer \
  --set eventHub.connectionString=$(az eventhubs eventhub authorization-rule keys list --namespace-name $eventhub -g $resourceGroup --eventhub-name dapreventhub --name daprauth --query primaryConnectionString -o tsv)
```

# State store example
To demo state management deploy pod1.yaml and check DAPR has injected side-car container. Then jump to container and use curl to call DAPR on loopback to store and read key.

```
kubectl apply -f pod1.yaml

kubectl describe pod pod1 | grep Image:
  Image:         tkubica/mybox
  Image:         docker.io/daprio/dapr:latest

kubectl exec -ti pod1 -- bash

curl -X POST http://localhost:3500/v1.0/state \
  -H "Content-Type: application/json" \
  -d '[
        {
          "key": "00-11-22",
          "value": "Tomas"
        }
      ]'

curl http://localhost:3500/v1.0/state/00-11-22
"Tomas"

kubectl delete -f pod1.yaml
```

# Pub/Sub example
For publish/subscribe demo first deploy pod1.yaml and keep window open. In new window deploy python1.yaml and jump to it using python process. Copy and paste application sub.py. That is explosing endpoint into which DAPR will send messages should they arrive. In pod1.yaml use curl to send message.

```
kubectl apply -f pod1.yaml
kubectl exec -ti pod1 -- bash

curl -X POST http://localhost:3500/v1.0/publish/orders \
	-H "Content-Type: application/json" \
	-d '{
       	     "orderCreated": "ABC01"
      }'
exit

kubectl apply -f python.yaml
kubectl exec -ti python1 -- python

kubectl delete -f python.yaml
kubectl delete -f pod.yaml
```

# Service discovery
TBD
```
kubectl apply -f pod1.yaml
kubectl apply -f nginx1.yaml

kubectl exec -ti pod1 -- bash

curl http://localhost:3500/v1.0/invoke/nginx1/method/
```

# Output binding to blob storage
In this example we will test output binding with Azure Blob Storage. Use DAPR API to create file in Blob storage.

```
kubectl apply -f pod1.yaml
kubectl exec -ti pod1 -- bash

curl -X POST http://localhost:3500/v1.0/bindings/binding-blob \
	-H "Content-Type: application/json" \
	-d '{ "metadata": {"blobName" : "myfile.json"}, 
      "data": {"mykey": "This is my value"}}'
exit

export storageConnection=$(az storage account show-connection-string -n $storageaccount -g $resourceGroup --query connectionString -o tsv)
az storage blob list -c daprcontainer -o table --connection-string $storageConnection

kubectl delete -f pod1.yaml
```

# Input binding from Event Hub
In this example we will have input binding from Azure Event Hub. Run Python container, jump to python process and copy and paste code in binding.py. Generate some event in Event Hub (eg. using summer.azure-event-hub-explorer extension in VS Code) and watch your code being called by DAPR and message content passed.

```
kubectl apply -f python.yaml
kubectl exec -ti python1 -- python

# Paste Python app binding.py and generate some event in Event Hub
```

# Actor model
TBD