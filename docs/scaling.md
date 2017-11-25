- [Horizontal Pod auto-scaling](#horizontal-pod-auto-scaling)
    - [Example container](#example-container)
    - [Using horizontal scaling](#using-horizontal-scaling)
    - [Clean up](#clean-up)
- [Cluster scaling](#cluster-scaling)
    - [Deploy application](#deploy-application)
    - [Scale cluster and check results](#scale-cluster-and-check-results)
    - [Clean up](#clean-up)
- [Cluster auto-scaling](#cluster-auto-scaling)

# Horizontal Pod auto-scaling
For unpredictable workloads we might want to scale number of instances in Deployment based on some metric. Kubernetes comes with built-in auto-scaling capability. In our example we will use simple CPU load metric, but it is also possible to have custom metric including something maintained in application itself.

In order for scaling to be effective we need to define resources for our pods, namely specify number of CPUs (can beeither full CPU or CPU share like 0.2) and memory. This instruct scheduler to place Pods on nodes with enough resources.

## Example container
In order to test reaction on CPU load we will use the following container that generate periodic CPU load (number of seconds as period lenght are configured via environmental variable): https://github.com/tkubica12/cpu-stress-docker

## Using horizontal scaling
We will deploy container with our stress application using Deployment concept in Kubernetes. We start with one instance. By defining env variable to container we set period of stress vs. idle to be 240 seconds.

```
kubectl create -f hpaDeployment.yaml
kubectl get pods -w
```

When pod is up, create scaler. We will watch how scaler sees metrics and what number of pods is running in deployment.

```
kubectl create -f hpaScaler.yaml
kubectl get hpa -w
```

## Clean up
```
kubectl delete -f hpaDeployment.yaml
kubectl delete -f hpaScaler.yaml
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
Now we will use az CLI to scale out cluster to 8 nodes.

```
az aks scale -n aks -g aks -c 8
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
We can monitor cluster for Pods that stay in pending state due to insufficient resources and when this happen initiate scale out operation. This is currently available as unsupported option for ACS engine, but not for AKS just yet.

To be updated when supported in AKS natively.
