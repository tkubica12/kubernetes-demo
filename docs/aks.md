# Deploying managed Kubernetes (AKS)
In this section we are going to deploy managed Kubernetes service in Azure. Make sure you have latest version of Azure CLI 2.0 installed. 

- [Deploying managed Kubernetes (AKS)](#deploying-managed-kubernetes-aks)
  - [Deploy AKS](#deploy-aks)
    - [Get credentials](#get-credentials)
    - [Download kubectl](#download-kubectl)
    - [Create VM for testing access within VNET](#create-vm-for-testing-access-within-vnet)
- [Scaling and autoscaling](#scaling-and-autoscaling)
  - [Horizontal Pod auto-scaling](#horizontal-pod-auto-scaling)
    - [Example container](#example-container)
    - [Gathering CPU metrics](#gathering-cpu-metrics)
    - [Using horizontal scaling](#using-horizontal-scaling)
    - [Advanced metrics from Azure services](#advanced-metrics-from-azure-services)
      - [Application Insights](#application-insights)
      - [Azure Monitor (Service Bus example)](#azure-monitor-service-bus-example)
    - [Clean up](#clean-up)
  - [Cluster auto-scaling](#cluster-auto-scaling)
- [Virtual Nodes](#virtual-nodes)
- [Windows nodes](#windows-nodes)

You can build basic cluster as simple as running this command:

```bash
az aks create -g MyResourceGroup -n MyManagedCluster
```

## Deploy AKS

In our demo we will go after more complex configuration using:
- Advanced Networking
- Azure Monitor
- Azure Active Directory integration
- Cluster autoscaling
- Virtual nodes (VM-less containers) - note current limitations (cannot coexist with Windows nodes, networking limitations)
- Multiple node pools
- Mix of Linux and Windows nodes
- Network Policy
- Availability Zones redundancy

First create virtual network and subnets.

```bash
export netRg=aksnetwork
export location=westeurope
az group create -n $netRg -l $location
az network vnet create -g $netRg \
        -n aks-network \
        --address-prefix 192.168.0.0/20 \
        --subnet-name aks-subnet \
        --subnet-prefix 192.168.0.0/22
az network vnet subnet create -n nodeless-subnet \
        -g $netRg \
        --vnet-name aks-network \
        --address-prefix 192.168.4.0/22
az network vnet subnet create -n testingvm-subnet \
        -g $netRg \
        --vnet-name aks-network \
        --address-prefix 192.168.8.0/24
```

We will integrate cluster with Azure Active Directory authentication. First follow documentation to register with AAD and get details: [https://docs.microsoft.com/en-us/azure/aks/aad-integration](https://docs.microsoft.com/en-us/azure/aks/aad-integration)

Store data in following environmental variables:
```
export aad-server-id=...
export aad-server-key=...
export aad-client-id=...
export aad-tenant-id=
```

Notes:
- If you do not want to integrate with AAD remove --aad-server-app-id,--aad-server-app-secret, --aad-client-app-id and --aad-tenant-id from az aks create command.
- Command will create Log Analytics workspace for monitoring. If you wish to use existing one, specify it with --workspace-resource-id
- Command will use default service principal of CLI or create one for you. In enterprise environments you might not have rights to create one so you can specify existing one with --service-principal and --client-secret
- In this step we will not enable virtual nodes
- Currently adding Windows nodes require Windows login profile to be present in AKS cluster and this is configurable during deployment. Therefore we will install aks-preview extension for CLI so we can use --windows-admin-password and --windows-admin-username (even we will not use Windows nodes initialy)


```bash
# Install CLI extension
az extension add --name aks-preview
# or update with: az extension update --name aks-preview

export aksRg=aks
export location=westeurope
export subnetId=$(az network vnet subnet show -g $netRg \
                -n aks-subnet \
                --vnet-name aks-network \
                --query id \
                -o tsv	  )

az group create -n $aksRg -l $location

az aks create -n aks -g $aksRg \
        --no-ssh-key \
        --kubernetes-version 1.15.7 \
        --zones 1 2 3 \
        --node-vm-size Standard_B2s \
        --network-plugin azure \
        --network-policy azure \
        --vnet-subnet-id $subnetId \
        --docker-bridge-address 172.17.0.1/16 \
        --dns-service-ip 192.168.9.10 \
        --service-cidr 192.168.9.0/24 \
        --max-pods 100 \
        --enable-addons monitoring \
        --enable-cluster-autoscaler \
        --min-count 3 \
        --max-count 9 \
        --windows-admin-password Azure12345678! \
        --windows-admin-username winadmin \
        --aad-server-app-id $aadserverid \
        --aad-server-app-secret $aadserverkey \
        --aad-client-app-id $aadclientid \
        --aad-tenant-id $aadtenantid
```

### Get credentials
Use Azure CLI to download cluster credentials and merge it to your kubectl configuration file on ~/.kube/config

```
az aks get-credentials -n aks -g $aksRg --admin
```

After merging this cluster becomes your current context. If you have stored multiple clusters you can use following commands to switch between them:

```
kubectl config use-context aks-admin
```

### Download kubectl

```
sudo az aks install-cli
```

### Create VM for testing access within VNET
```
export vmSubnetId=$(
                az network vnet subnet show -g $netRg \
                -n testingvm-subnet \
                --vnet-name aks-network \
                --query id \
                -o tsv	  )
export testingvmResourceGroup=akstestingvm
export location=westeurope

az group create -n $testingvmResourceGroup -l $location
az vm create -n mytestingvm \
        -g $testingvmResourceGroup \
        --admin-username tomas \
        --admin-password Azure12345678 \
        --authentication-type password \
        --image UbuntuLTS \
        --nsg "" \
        --subnet $vmSubnetId \
        --size Standard_B1s

export vmIp=$(az network public-ip show -n mytestingvmPublicIP -g akstestingvm --query ipAddress -o tsv)
ssh tomas@$vmIp
```

# Scaling and autoscaling
There few aspects when it comes to scaling a autoscaling:
- Scaling number of Pod replicas (Horizontal Pod Autoscaler)
- Advanced metrics for HPA (going beyond CPU a RAM including external metrics such as APM or queue length)
- Scaling Pod resource limits (Vertical Pod Autoscaler)
- Scaling to 0 (serverless, eg. KEDA, Osiris, Knative)
- Scaling cluster nodes

## Horizontal Pod auto-scaling
For unpredictable workloads we might want to scale number of instances in Deployment based on some metric. Kubernetes comes with built-in auto-scaling capability. In our example we will use simple CPU load metric, but it is also possible to have custom metric including something maintained in application itself.

In order for scaling to be effective we need to define resources for our pods, namely specify number of CPUs (can beeither full CPU or CPU share like 0.2) and memory. This instruct scheduler to place Pods on nodes with enough resources.

### Example container
In order to test reaction on CPU load we will use the following container that generate periodic CPU load (number of seconds as period lenght are configured via environmental variable) with source in folder cpu-stress.

### Gathering CPU metrics
Integrated HPA is using metrics-server to gather CPU load, but scaler can be configured to support customer metrics also.

If you are using AKS metrics-server is already deployed.

### Using horizontal scaling
We will deploy container with our stress application using Deployment concept in Kubernetes. We start with one instance. By defining env variable to container we set period of stress vs. idle to be 600 seconds (we are using 10 minutes here as default cooldown of HPA is 5 minutes).

```
kubectl create -f hpaDeployment.yaml
kubectl create -f hpaScaler.yaml
kubectl get hpa -w
```

### Advanced metrics from Azure services
CPU might not be the best metric to base our autoscaling metrics on. You can deploy more advanced solution such as Prometheus project into your AKS cluster, but that might be complex and not needed when you are using Azure Application Insights to monitor your applications in Kubernetes or leverage PaaS components such as Azure Service Bus.

There is open source project in Alpha stage that brings Azure Monitor as External Metrics (eg. for using Service Bus metrics in HPA) and Application Insights as Custom Metrics (eg. for using requests per second in HPA). We will deploy this component, but first let's create Secret with access details. Note that if you use Application Insights only, you can specify just app id and key. On the other hand if you use Azure Monitor only then just tenant id, client id and client secret is required.

```
kubectl create namespace custom-metrics
mkdir azure
cd azure
printf $appinsightsappid > APP_INSIGHTS_APP_ID
printf $appinsightskey > APP_INSIGHTS_KEY
printf $tenant > AZURE_TENANT_ID
printf $principal > AZURE_CLIENT_ID
printf $client_secret > AZURE_CLIENT_SECRET
kubectl create secret generic azure-api -n custom-metrics --from-file=.
cd ..
rm -rf azure
```

Now we can deploy adapter.
```
kubectl apply -f hpaAppInsightsAdapter.yaml
```

#### Application Insights
In our example we will deploy Node.JS application that is monitored by Application Insights and use experimental Custom Metrics implementation to access counters in Application Insights from Kubernetes cluster to base our autoscaling policy on.

First we need to provision Application Insights in Azure. We will get instrumentation key that our application will use to connect to our instance. We will also generate appid and key for API access to metrics by Custom Metrics implementation. Store all of those in Kubernetes Secrets.

Let's create instrumentation key to be used in our application as Secret into current namespace (default in my case).

```
kubectl create secret generic appinsights \
    --from-literal=APPINSIGHTS_INSTRUMENTATIONKEY=$appinsightsinstrumentationkey
```

Let's deploy our application. We will use Deployment and Service and pass instrumentation key from Secret.
```
kubectl apply -f hpaAppInsightsDeployment.yaml
```

Now we will deploy HPA scaler based on requests per second metrics comming from Application Insights. For demo purposes we will use target rate of 2 RPS. If RPS is more then 2, HPA will be creating additional Pods up to maximum limit (10 in my case).

Configure HPA, generate load and check how it behaves.
```
kubectl apply -f hpaAppInsightsScaler.yaml
watch kubectl get hpa,pods
```

#### Azure Monitor (Service Bus example)
You might be using Kubernetes for stateless applications and leverage PaaS services in Azure for state and integration. For example you can use Azure Service Bus to provide reliable messaging service. If you run your stateless consumers in Kubernetes we can use HPA to scale number of consumer instances based on queue lenght in Azure Service Bus.

We will create Secret with connection string to your Service Bus. Then we deploy single Pod that will generate 1000 messages and Deployment with 1 replica as receiver (Pod will consume 1 message per second). Last point is to create HPA to autoscale receivers so too long queue is serviced more quickly and when short HPA will scale-in.

```
kubectl create secret generic servicebus --from-literal=SERVICEBUS_CONNECTION=$servicebus
kubectl apply -f hpaBusSender.yaml
kubectl apply -f hpaBusReceiverDeployment.yaml
kubectl apply -f hpaBusScaler.yaml
watch kubectl get hpa,pods
```

### Clean up
```
kubectl delete -f hpa*.yaml
kubectl delete secret servicebus
kubectl delete secret appinsights
kubectl delete namespace custom-metrics
```

## Cluster auto-scaling
AKS monitors cluster for Pods that stay in pending state due to insufficient resources and when this happen initiate scale out operation. 

Let's create Deployment with need for 0.5 CPU and 10 instances. This will be outside of our cluster capacity.

```
kubectl create -f clusterScalingDeployment.yaml
```

After some time check how many Pods are in Running state. Based on size of our cluster we expect some Pods to stay in Pending state as there is not enough capacity in our cluster to run all 10 instances. When you check logs on one of Pods in Pending state you will see

```bash
kubectl get pods -o wide
kubectl get deployments
kubectl describe pod myclusterscaling-deployment-9dbd69c78-ktqjv

# Type     Reason            Age                From                Message
#  ----     ------            ----               ----                -------
#  Warning  FailedScheduling  77s (x2 over 77s)  default-scheduler   0/3 nodes are available: 3 Insufficient cpu.
#  Normal   TriggeredScaleUp  73s                cluster-autoscaler  pod triggered scale-up: [{aks-nodepool1-40944020-vmss 3->4 (max: 9)}]
```

After few minutes you should see additional node come up and all Pods in Running state. When you delete deployment cluster will scale back.

# Virtual Nodes
Enable virtual node addon.

```bash
az aks enable-addons \
    --resource-group $aksRg \
    --name aks \
    --addons virtual-node \
    --subnet-name nodeless-subnet
```

This addon has deployed project Virtual Kubelet and we should see virtual node ready:

```bash
kubectl get nodes
kubectl describe node virtual-node-aci-linux
```

Note there is Taint on this node (virtual-kubelet.io/provider=azure:NoSchedule) so only Pods that explicitly tolerate this taint can be scheduled. Check [Advanced scheduling](./scheduling.md) for more details.

Deploy web application on virtual node.

```bash
kubectl apply -f deploymentWebVirtualNode.yaml
kubectl apply -f serviceWebExtPublic.yaml
```

Cleanup

```bash
kubectl delete -f deploymentWebVirtualNode.yaml
kubectl delete -f serviceWebExtPublic.yaml
az aks disable-addons \
    --resource-group $aksRg \
    --name aks \
    --addons virtual-node
```

# Windows nodes
As of AKS 1.15 Windows nodes are in preview. Make sure you have install CLI preview extension and registered Windows nodes feature.

```bash
# Add CLI extension
az extension add --name aks-preview
# or update with: az extension update --name aks-preview

# Register feature
az feature register --name WindowsPreview --namespace Microsoft.ContainerService

# Check state of feature registration
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/WindowsPreview')].{Name:name,State:properties.state}"

# Update provider state
az provider register --namespace Microsoft.ContainerService
```

On cluster with Windows profile let's add additional nodepool with Windows nodes.

```bash
az aks nodepool add \
    --resource-group $aksRg \
    --cluster-name aks \
    --os-type Windows \
    --name npwin \
    --node-count 1 \
    --kubernetes-version 1.15.5 \
    --node-taints "os=windows:NoSchedule"
```

During provisioning we have added Taint to Windows nodes so unless explicitly "tolerated" standard Pods (with Linux images) will never get scheduled to Windows nodes. See [Advanced scheduling](./scheduling.md) for more details on Taints.

Deploy IIS Pod and expose via Service.

```bash
kubectl apply -f IIS.yaml
```

Clean up and remove Windows nodes

```bash
kubectl delete -f IIS.yaml
az aks nodepool delete -g $aksRg --cluster-name aks -n npwin
```