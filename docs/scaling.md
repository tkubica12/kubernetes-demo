# Scaling your apps and cluster
In this section we will explore Pod scaling and cluster scaling.

- [Scaling your apps and cluster](#scaling-your-apps-and-cluster)
- [Horizontal Pod auto-scaling](#horizontal-pod-auto-scaling)
    - [Example container](#example-container)
    - [Gathering CPU metrics](#gathering-cpu-metrics)
    - [Using horizontal scaling](#using-horizontal-scaling)
    - [Clean up](#clean-up)
- [Cluster scaling](#cluster-scaling)
    - [Deploy application](#deploy-application)
    - [Scale cluster and check results](#scale-cluster-and-check-results)
    - [Clean up](#clean-up)
- [Cluster auto-scaling](#cluster-auto-scaling)
    - [Prepare configuration details as Secret](#prepare-configuration-details-as-secret)
    - [Deploy cluster autoscaler](#deploy-cluster-autoscaler)
    - [Cleanup](#cleanup)

# Horizontal Pod auto-scaling
For unpredictable workloads we might want to scale number of instances in Deployment based on some metric. Kubernetes comes with built-in auto-scaling capability. In our example we will use simple CPU load metric, but it is also possible to have custom metric including something maintained in application itself.

In order for scaling to be effective we need to define resources for our pods, namely specify number of CPUs (can beeither full CPU or CPU share like 0.2) and memory. This instruct scheduler to place Pods on nodes with enough resources.

## Example container
In order to test reaction on CPU load we will use the following container that generate periodic CPU load (number of seconds as period lenght are configured via environmental variable): https://github.com/tkubica12/cpu-stress-docker

## Gathering CPU metrics
Integrated HPA is using metrics-server to gather CPU load, but scaler can be configured to support customer metrics also.

As time of this writing AKS cluster does not come with metrics-server by default (it uses older Heapster), so for now we will deploy iy manually.
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

## Clean up
```
kubectl delete -f hpaDeployment.yaml
kubectl delete -f hpaScaler.yaml
helm delete metrics --purge
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

** Please note that version mentioned here v1.2.2 is not compatible with AKS clusters that use Advanced Networking **

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

There is hard dependency between Kubernetes version and autoscaler version. In our example we expect AKS running 1.10.x and therefore we use cluster autoscaler 1.2.x. You can change this in Deployment definition:
```
      - image: k8s.gcr.io/cluster-autoscaler:v1.2.2
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