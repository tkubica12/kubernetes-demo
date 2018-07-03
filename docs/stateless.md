# Using stateless app farms with Deployments and Services
This set of demos focus on stateless applications like APIs or web frontend. We will deploy application, balance it internally and externally, do rolling upgrade, deploy both Linux and Windows containers and make sure they can access each other.

- [Using stateless app farms with Deployments and Services](#using-stateless-app-farms-with-deployments-and-services)
    - [Switch to our AKS cluster](#switch-to-our-aks-cluster)
    - [Deploy multiple pods with Deployment](#deploy-multiple-pods-with-deployment)
    - [Create service to balance traffic internally](#create-service-to-balance-traffic-internally)
    - [Create externally accessible service with Azure LB with Public IP](#create-externally-accessible-service-with-azure-lb-with-public-ip)
    - [Create externally accessible service with Azure LB with Private IP](#create-externally-accessible-service-with-azure-lb-with-private-ip)
    - [Predictable (static) external IP addresses](#predictable-static-external-ip-addresses)
    - [Session persistence](#session-persistence)
    - [Preserving client source IP](#preserving-client-source-ip)
        - [Why Kubernetes do SNAT by default](#why-kubernetes-do-snat-by-default)
        - [How can you preserve client IP and what are negative implications](#how-can-you-preserve-client-ip-and-what-are-negative-implications)
        - [Recomendation of using this with Ingress only and then use X-Forwarded-For](#recomendation-of-using-this-with-ingress-only-and-then-use-x-forwarded-for)
    - [Rolling upgrade](#rolling-upgrade)
    - [Canary releases with multiple deployments under single Service](#canary-releases-with-multiple-deployments-under-single-service)
    - [Deploy IIS on Windows pool (currently only for ACS mixed cluster, no AKS)](#deploy-iis-on-windows-pool-currently-only-for-acs-mixed-cluster-no-aks)
    - [Test Linux to Windows communication (currently only for ACS mixed cluster, no AKS)](#test-linux-to-windows-communication-currently-only-for-acs-mixed-cluster-no-aks)
    - [Clean up](#clean-up)

Most parts of this demo works in AKS except for Windows containers, for which we currently need to use custom ACS engine.

## Switch to our AKS cluster
```
kubectl use-context akscluster
```

## Deploy multiple pods with Deployment
We are going to deploy simple web application with 3 instances.

```
kubectl create -f deploymentWeb1.yaml
kubectl get deployments -w
kubectl get pods -o wide
```

## Create service to balance traffic internally
Create internal service and make sure it is accessible from within Kubernetes cluster. Try multiple times to se responses from different nodes in balancing pool.

```
kubectl create -f podUbuntu.yaml
kubectl create -f serviceWeb.yaml
kubectl get services
kubectl exec ubuntu -- curl -s myweb-service
```

## Create externally accessible service with Azure LB with Public IP
In this example we make service accessible for users via Azure Load Balancer leveraging public IP address.

```
kubectl create -f serviceWebExtPublic.yaml

export extPublicIP=$(kubectl get service myweb-service-ext-public -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl $extPublicIP
```

## Create externally accessible service with Azure LB with Private IP
In this example we make service accessible for internal users via Azure Load Balancer with private IP address so service only from VNET (or peered networks or on-premises network connected via S2S VPN or ExpressRoute).

```
kubectl create -f serviceWebExtPrivate.yaml
```

To test we will connect to VM that runs in the same VNET.
```
export vmIp=$(az network public-ip show -n mytestingvmPublicIP -g akstestingvm --query ipAddress -o tsv)
export extPrivateIP=$(kubectl get service myweb-service-ext-private -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ssh tomas@$vmIp curl $extPrivateIP
```

## Predictable (static) external IP addresses
Kubernetes Service together with Azure will assign external IP for you - either free Private IP or create new Public IP. Sometimes you might need this to be more predictable. For example you can create Public IP in your resource group in advance and setup additional systems (DNS records, whitelisting). You specify existing public or private IP in Service definition statically.

```
kubectl create -f serviceWebExtPrivateStatic.yaml
```
## Session persistence
By default service does round robin so your client can connect to different instance every request. This should not be problem with truly stateless scenarios and does allow you for very good balancing. But in some cases even stateless applications might benefit from session persistence:
* You are using canary deployment some some instances might run newer version of your app then others and such inconsistencies might be unwanted for user experience
* You are terminating TLS right in instances and moving to another means renegotiating and therefore increase latency
* Your API use paging where client request data page by page and you are prefetching data from database in advance. Connecting to different instance can have performance penalty (data not prefetched)

```
kubectl create -f serviceWebSession.yaml
```

Using podUbuntu from previous demos check out results. You should see different instances when talking to myweb-service, but not when talking to myweb-server-session.

```
kubectl exec ubuntu -- /bin/bash -c 'for i in {1..10}; do curl -s myweb-service; done'
kubectl exec ubuntu -- /bin/bash -c 'for i in {1..10}; do curl -s myweb-service-session; done'
```

## Preserving client source IP
By default Kubernetes Service is doing SNAT before sending traffic to Pod so client IP information is lost. This might not be problem unless you want to:
* Whitelisting access to service based on source IP addresses
* Log client IP address (legal requirement, location tracking, ...)

### Why Kubernetes do SNAT by default
When you deploy service of type LoadBalancer underlying IaaS will deploy load balancer, Azure LB in our case. This balancer is configured to send traffic to any node of your cluster. If traffic arrives on node that does not hoste any instance (Pod) of that Service, it will proxy traffic to different node. Current Kubernetes implementation need to do SNAT for this to work.

### How can you preserve client IP and what are negative implications
In Azure you can use externalTrafficPolicy (part of spec section of Service definition) set to Local. This ensures that Azure LB does balance traffic only to nodes where Pod replica runs and Service on node is sending traffic only to Pods available locally. With that there is no need to reroute traffic to different node, no added latency and  there is no SNAT required. This settings preserves actual client IP in packet entering Pod.

Using this might create suboptimal load distribution if number of replicas is close to number of nodes or more. Under such conditions some nodes might get more than one replica (Pod) running. Since there is no rerouting now traffic distribution is not done on Pods level but rather Nodes level. Example:

node1 -> pod1, pod4
node2 -> pod2
node3 -> pod3

With default configuration each pod will get 25% of new connections. With externalTrafficPolicy set to Local, each node will get 33% of new connections. Therefor pod1 and pod4 will get just 16,5% connections each while pod2 and pod3 will get 33% each.

### Recomendation of using this with Ingress only and then use X-Forwarded-For
Good solution if you need client IP information is to use it for [Ingress](docs/networking.md), but not for other Services. By deploying ingress controller in Service with externalTrafficPolicy Local, your nginx proxy will see client IP. This means you can do whitelisting (source IP filters) in you Ingress definition. Traffic distribution problem is virtualy non existent because you typically run ingress on one or few nodes in cluster, but rarely you want more replicas then number of nodes.

## Rolling upgrade
We will now do rolling upgrade of our application to new version. We are going to change deployment to use different container with v2 of our app.
```
kubectl apply -f deploymentWeb2.yaml
```

Watch pods being rolled
```
kubectl get pods -w
```

## Canary releases with multiple deployments under single Service
You might want to have tighter control about rolling upgrade. For examle you want canary release like serving small percentage of clients new version for long enough time to gather feedback (hours). Or you want to control ratio between old and new version over time (for example roll 20% of requests every hour).

TBD

## Deploy IIS on Windows pool (currently only for ACS mixed cluster, no AKS)
Let's now deploy Windows container with IIS.

```
kubectl create -f IIS.yaml
kubectl get service
```

## Test Linux to Windows communication (currently only for ACS mixed cluster, no AKS)
In this demo we want to make sure our Linux and Windows containers can talk to each other. Connect from Linux container to internal service endpoint of IIS.

```
kubectl exec ubuntu -- curl -s myiis-service-ext
```

## Clean up
```
kubectl delete -f serviceWebExtPublic.yaml
kubectl delete -f serviceWebExtPrivate.yaml
kubectl delete -f serviceWebExtPrivateStatic.yaml
kubectl delete -f serviceWeb.yaml
kubectl delete -f podUbuntu.yaml
kubectl delete -f deploymentWeb1.yaml
kubectl delete -f deploymentWeb2.yaml
kubectl delete -f IIS.yaml

```
