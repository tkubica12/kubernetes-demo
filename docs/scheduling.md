# Advanced scheduling
Kubernetes comes with advanced scheduler and couple of concepts to influence where your Pods will be scheduler. In this chapter we will look into Node affinity, Pod affinity and anti-affinity, Taints and Pod priorities.

- [Advanced scheduling](#advanced-scheduling)
- [Node affinity](#node-affinity)
- [Taints and tolerations](#taints-and-tolerations)
- [Pod affinity and anti-affinity](#pod-affinity-and-anti-affinity)
- [Pod priority](#pod-priority)


# Node affinity
By default Kubernetes scheduler will place Pods to Nodes using various built-in scoring mechanisms. We will use Node Affinity to influence where our Pods will be placed. Please note there is also Kubernetes construct NodeSelector, but Node Affinity can achieve the same thing and much more and is expected NodeSelector will be deprecated when Node Affinity goes to stable.

First let's check default lables on our nodes (I have 3 in my cluster).
```
kubectl get nodes --show-labels
```

We will now put additional labels to our nodes
```
kubectl label nodes aks-nodepool1-38238592-0 color=blue
kubectl label nodes aks-nodepool1-38238592-1 color=blue
kubectl label nodes aks-nodepool1-38238592-2 color=red
kubectl get nodes --show-labels
```

We will now deploy Pod and require it to be place on node with label key color with value red.
```
kubectl apply -f podNodeAffinityRequired.yaml
kubectl get pods -o wide
```

Previous requirement was hard. If scheduler could not fullfil our requirement, Pod will not be scheduled. We can also use soft rules to signal our preference and can use multiple ones as order list. This can also be combined with hard rules so as an example we might require Pod to run on node with strong CPU and preferably Premium SSDs or if not available on Standard SSDs (or any other strong CPU node if no SSD is available at all).

In our example we prefer to run on orange node (which we do not currenlty have) and if not available on Red node.
```
kubectl apply -f podNodeAffinityPreferred.yaml
kubectl get pods -o wide
```

Remove Pods.
```
kubectl delete -f podNodeAffinityRequired.yaml
kubectl delete -f podNodeAffinityPreferred.yaml
```

# Taints and tolerations
Node affinity is about attracting Pod to Nodes. Taints are exact opposite and cause Pods that do not specifically tolerate this condition to avoid getting on those Nodes. There are tree possible effects to be configured. PreferNoSchedule will try to avoid that Node. NoSchedule is hard version that will not schedule Pod on that Node no matter what. NoExec is strongest "retroactive" option that is not only for new Pods being scheduled, but also for existing Pods (those are invicted). Pods can be configured to explicitely tolerate certain taint.

Why use taints when something similar can be achieved with Node affinity? Taints are more like blacklist so when you have 100 nodes and need to blacklist one it is way easier that whitelist remaining 99. But more importantly when Pod have no Node affinity configured it can be placed on any Node, but never on taint Node (in other word Pods in default configuration will get Nodes blacklisted so you can prevent disasters).

Why use taints and tolerations?
* Flag slow nodes not OK for production (and let Dev Pods tolerate this)
* Flag nodes behind Virtual Kubelet so default Pods will node use those (eg. IoT devices behind Azure IoT Hub might behave as Virtual Kubelet and you certainly do not want to run your systems accidentaly on raspberry in your factory)
* Flag nodes you need to put out of service (NoExec will evacuate existing Pods also)
* Flag nodes that are very specific and expensive such as GPU nodes (you want to prevent web Pods in default configuration to be scheduled on such expensive resource so you will use taint and your machine learning Pods will have toleration on this taint)

First let's taint one of our Nodes
```
kubectl taint nodes aks-nodepool1-38238592-2 devonly=goaway:NoSchedule
```

We will now deploy two Deploments with 5 replicas. First one will be standard and second one will have toleration.
```
kubectl apply -f deploymentNoToleration.yaml
kubectl apply -f deploymentToleration.yaml
kubectl get pods -o wide
```

Remove Taints and Deployments
```
kubectl taint nodes aks-nodepool1-38238592-2 devonly:NoSchedule-
kubectl delete -f deploymentNoToleration.yaml
kubectl delete -f deploymentToleration.yaml
```

# Pod affinity and anti-affinity
We might have need to place two Pods on single Node to reduce latency. Example might be application Pod and cache Pod. As with Node affinity we can set hard rules (required) and soft rules (preferred). As opposed to Node affinity we are not defining what Node we want. We do not care what specific Node, but want Pods to get on the same one.

First we will try affinity example. Note we can make Pods required to be on the same node by using topologyKey kubernetes.io/hostname (which is unique for each node). Sometimes you do not need stricly the same node, but the same group of Nodes - for example if you would have two groups of 5 nodes with 10G network within group and just 1G between groups you might want your two Pods to land in the same group. In that case your topologyKey would be group label.

Deploy two Pods and make sure they land on the same Node.
```
kubectl apply -f podAffinity1.yaml
kubectl apply -f podAffinity2.yaml
kubectl get pods -o wide
```

Anti-affinity is opposite and is typically used to achieve HA by placing Pods on Nodes supported by independent infrastructure (different server, rack or event data center). In Azure Kubernetes Service information about Failure domains are propagated to cluster automatically as Node labels failure-domain.kubernetes.io/zone. Default scheduler behavior is to spread Pods in ReplicaSets (Deployments) based on that standard label. You do not have to configure anything to let your Pods be spread across failure domains.

Nevertheless we can try this. Let's deploy two Pods with anti-affinity based on our color labels.
```
kubectl apply -f podAntiAffinity.yaml
kubectl get pods -o wide
```

# Pod priority

TBD