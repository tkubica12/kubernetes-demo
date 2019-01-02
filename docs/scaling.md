# Scaling your apps and cluster
In this section we will explore Pod scaling and cluster scaling.

- [Scaling your apps and cluster](#scaling-your-apps-and-cluster)
- [Horizontal Pod auto-scaling](#horizontal-pod-auto-scaling)
  - [Example container](#example-container)
  - [Gathering CPU metrics](#gathering-cpu-metrics)
  - [Using horizontal scaling](#using-horizontal-scaling)
  - [Advanced metrics from Azure services](#advanced-metrics-from-azure-services)
    - [Application Insights](#application-insights)
    - [Azure Monitor (Service Bus example)](#azure-monitor-service-bus-example)
  - [Clean up](#clean-up)
- [Cluster scaling](#cluster-scaling)
  - [Deploy application](#deploy-application)
  - [Scale cluster and check results](#scale-cluster-and-check-results)
  - [Clean up](#clean-up-1)
- [Cluster auto-scaling](#cluster-auto-scaling)
  - [Prepare configuration details as Secret](#prepare-configuration-details-as-secret)
  - [Deploy cluster autoscaler](#deploy-cluster-autoscaler)
  - [Cleanup](#cleanup)

# Horizontal Pod auto-scaling
For unpredictable workloads we might want to scale number of instances in Deployment based on some metric. Kubernetes comes with built-in auto-scaling capability. In our example we will use simple CPU load metric, but it is also possible to have custom metric including something maintained in application itself.

In order for scaling to be effective we need to define resources for our pods, namely specify number of CPUs (can beeither full CPU or CPU share like 0.2) and memory. This instruct scheduler to place Pods on nodes with enough resources.

## Example container
In order to test reaction on CPU load we will use the following container that generate periodic CPU load (number of seconds as period lenght are configured via environmental variable) with source in folder cpu-stress.

## Gathering CPU metrics
Integrated HPA is using metrics-server to gather CPU load, but scaler can be configured to support customer metrics also.

If you are using AKS with Kubernetes version 1.11.1 or later there is metrics-server deployed by default. For older version you can deploy it yourself via Helm.
```
helm repo update
helm install stable/metrics-server --name metrics
```

## Using horizontal scaling
We will deploy container with our stress application using Deployment concept in Kubernetes. We start with one instance. By defining env variable to container we set period of stress vs. idle to be 600 seconds (we are using 10 minutes here as default cooldown of HPA is 5 minutes).

```
kubectl create -f hpaDeployment.yaml
kubectl create -f hpaScaler.yaml
kubectl get hpa -w
```

## Advanced metrics from Azure services
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

### Application Insights
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

### Azure Monitor (Service Bus example)
You might be using Kubernetes for stateless applications and leverage PaaS services in Azure for state and integration. For example you can use Azure Service Bus to provide reliable messaging service. If you run your stateless consumers in Kubernetes we can use HPA to scale number of consumer instances based on queue lenght in Azure Service Bus.

We will create Secret with connection string to your Service Bus. Then we deploy single Pod that will generate 1000 messages and Deployment with 1 replica as receiver (Pod will consume 1 message per second). Last point is to create HPA to autoscale receivers so too long queue is serviced more quickly and when short HPA will scale-in.

```
kubectl create secret generic servicebus --from-literal=SERVICEBUS_CONNECTION=$servicebus
kubectl apply -f hpaBusSender.yaml
kubectl apply -f hpaBusReceiverDeployment.yaml
kubectl apply -f hpaBusScaler.yaml
watch kubectl get hpa,pods
```


## Clean up
```
kubectl delete -f hpa*.yaml
kubectl delete secret servicebus
kubectl delete secret appinsights
kubectl delete namespace custom-metrics
```

# Cluster scaling
When scaling Pod deployments (either manualy or using horizontal pod autoscaling feature) and applying resource limits scheduler tracks resource allocation of nodes. At some point scheduler might not find node with enough free resources to place Pod on. In such cases Kubernetes will keep trying schedule Pod, but will wait some existing workload is scaled down. In order to provide additional resources to cluster we might want to scale whole cluster out (add worker/agent nodes to cluster).

## Deploy application
Let's create Deployment with need for 0.5 CPU and 10 instances.

```
kubectl create -f clusterScalingDeployment.yaml
```

After some time check how many Pods are in Running state. Based on size of our cluster we expect some Pods to stay in Pending state as there is not enough capacity in our cluster to run all 10 instances.

```
kubectl get pods -o wide
kubectl get deployments
```

## Scale cluster and check results
Now we will use az CLI to scale out cluster to 6 nodes.

```
az aks scale -n akscluster -g aksgroup -c 6
```

After some time check our cluster now has more nodes and we have addedd enough resources for all our Pods to come to running state.

```
kubectl get nodes
kubectl get pods -o wide
```

## Clean up
Delete deployment and scale cluster in.

```
kubectl delete -f clusterScalingDeployment.yaml
az aks scale -n aks -g aks -c 2
```

# Cluster auto-scaling
We can monitor cluster for Pods that stay in pending state due to insufficient resources and when this happen initiate scale out operation. Implementation is available for AKS, ACS engine and custom solutions also with Availability Set or Virtual Machine Scale Set here: (https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/azure/README.md)

AKS currently does not deploy this component in automated way so we will do that manually.

## Prepare configuration details as Secret
First we need to gather configuration information for autoscaler as it needs to talk to Azure in order to scale our deployment. Resource group details, service principal account and other parameters will be pushed into Kubernetes Secret.

```
export aksRg=aksgroup

mkdir scaler
printf $principal > scaler/ClientID
printf $client_secret > scaler/ClientSecret
printf $aksRg > scaler/ResourceGroup
printf $subscription > scaler/SubscriptionID
printf $tenant > scaler/TenantID
printf AKS > scaler/VMType
printf akscluster > scaler/ClusterName
printf MC_aksgroup_akscluster_westeurope > scaler/NodeResourceGroup

kubectl create secret generic cluster-autoscaler-azure --from-file=scaler/ --namespace kube-system
rm -rf scaler
```

In clusterAutoScaling.yaml locate following command that is passed to deployment. Keep nodepool1 (default naming for node pool in AKS) and you can change minimum and maximum number of nodes. Our example scales between 1 to 10 nodes.
```
    - --nodes=1:10:nodepool1
```

## Deploy cluster autoscaler
```
kubectl apply -f clusterAutoScaling.yaml
```

## Cleanup

```
kubectl delete -f clusterAutoScaling.yaml
kubectl delete secrets/cluster-autoscaler-azure --namespace kube-system
```