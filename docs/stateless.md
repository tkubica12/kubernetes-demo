# Using stateless app farms
This set of demos focus on stateless applications like APIs or web frontend. We will deploy application, balance it internally and externally, do rolling upgrade, deploy both Linux and Windows containers and make sure they can access each other.

- [Using stateless app farms](#using-stateless-app-farms)
    - [Switch to our AKS or mixed ACS cluster](#switch-to-our-aks-or-mixed-acs-cluster)
    - [Deploy multiple pods with Deployment](#deploy-multiple-pods-with-deployment)
    - [Create service to balance traffic internally](#create-service-to-balance-traffic-internally)
    - [Create externally accessible service with Azure LB with Public IP](#create-externally-accessible-service-with-azure-lb-with-public-ip)
    - [Create externally accessible service with Azure LB with Private IP](#create-externally-accessible-service-with-azure-lb-with-private-ip)
    - [Create externally accessible service with L7 proxy (Kubernetes ingress)](#create-externally-accessible-service-with-l7-proxy-kubernetes-ingress)
        - [Make sure Helm is installed](#make-sure-helm-is-installed)
        - [Deploy nginx ingress](#deploy-nginx-ingress)
        - [Prepare certificate and store it as Kubernetes secret](#prepare-certificate-and-store-it-as-kubernetes-secret)
        - [Create DNS record](#create-dns-record)
        - [Create ingress for our service](#create-ingress-for-our-service)
        - [Test](#test)
    - [Preserving client source IP](#preserving-client-source-ip)
        - [Why Kubernetes do SNAT by default](#why-kubernetes-do-snat-by-default)
        - [How can you preserve client IP and what are negative implications](#how-can-you-preserve-client-ip-and-what-are-negative-implications)
        - [Recomendation of using this with Ingress only and then use X-Forwarded-For](#recomendation-of-using-this-with-ingress-only-and-then-use-x-forwarded-for)
    - [Upgrade](#upgrade)
    - [Deploy IIS on Windows pool (currently only for ACS mixed cluster, no AKS)](#deploy-iis-on-windows-pool-currently-only-for-acs-mixed-cluster-no-aks)
    - [Test Linux to Windows communication (currently only for ACS mixed cluster, no AKS)](#test-linux-to-windows-communication-currently-only-for-acs-mixed-cluster-no-aks)
    - [Clean up](#clean-up)

Most parts of this demo works in AKS except for Windows containers, for which we currentlz need to use custom ACS engine.

## Switch to our AKS or mixed ACS cluster
```
kubectx aks
```

or mixed ACS engine

```
kubectx mojeacsdemo
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
ssh tomas@mykubeextvm.westeurope.cloudapp.azure.com
curl 10.240.0.9
```

## Create externally accessible service with L7 proxy (Kubernetes ingress)
In case we want L7 balancing, URL routing and SSL acceleration we need to use ingress controler with NGINX implementation. This will deploy http proxy into Kubernetes accessible via external IP (leveraging Azure LB and Azure DNS). Proxy then handles traffic routing to internal services in cluster and provides SSL acceleration.

### Make sure Helm is installed
Please refer to this chapter for installing Helm:

[Package applications with Helm](docs/helm.md)

### Deploy nginx ingress
First we need to deploy L7 proxy that will work as Kubernetes Ingress balancer. We are using helm to easily install complete package (more on Helm later in this demo).

If you run on cluster with no RBAC (currently AKS) use this:
```
helm install --name ingress stable/nginx-ingress
```

If you run on cluster with RBAC (our mixed ACS cluster example) use this:
```
helm install --name ingress stable/nginx-ingress --set rbac.create
```

### Prepare certificate and store it as Kubernetes secret 
We will want to use TLS encryption (HTTPS). For demo purposes we will now create self-signed certificate.

```
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=mykubeapp.azure.tomaskubica.cz'

kubectl create secret tls mycert --key key.pem --cert cert.pem

rm key.pem
rm cert.pem
```

### Create DNS record
We need to register nginx-ingress public IP address with DNS server. In this demo we use Azure DNS.

```
export ingressIP=$(kubectl get service ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

az network dns record-set a add-record -a $ingressIP -n mykubeapp -g shared-services -z azure.tomaskubica.cz
```

### Create ingress for our service
We are ready to go. Let's create ingress service that will reference (expose) internal service we have created previously.

```
kubectl create -f ingressWeb.yaml
```

### Test
Access app at https://mykubeapp.azure.tomaskubica.cz/myweb

Because certificate is self-signed (not trusted) use this to test:
```
curl -k https://mykubeapp.azure.tomaskubica.cz/myweb
```

Print certificate
```
openssl s_client -showcerts -servername mykubeapp.azure.tomaskubica.cz -connect mykubeapp.azure.tomaskubica.cz:443 2>/dev/null | openssl x509 -inform pem -noout -text
```

## Preserving client source IP
By default Kubernetes Service is doing SNAT before sending traffic to Pod so client IP information is lost. This might not be problem unless you want to:
* Whitelist access to service based on source IP addresses
* Log client IP address (legal requirement, location tracking, ...)

### Why Kubernetes do SNAT by default
When you deploy service of type LoadBalancer underlying IaaS will deploy load balancer, Azure LB in our case. This balancer is configured to send traffic to any node of your cluster. If traffic arrives on node that does not hoste any instance (Pod) of that Service, it will proxy traffic to different node. Current Kubernetes implementation need to do SNAT for this to work.

### How can you preserve client IP and what are negative implications
In Azure you can use externalTrafficPolicy (part of spec section of Service definition) set to Local. This ensures that Azure LB does balance traffic only to nodes where Pod replica runs. With that there is no need to reroute traffic to different node and so there is no SNAT required. This settings preserves actual client IP in packet entering Pod.

Using this might create suboptimal routing distribution if number of replicas close to number of nodes or more. Under such conditions some nodes might get more than one replica (Pod) running. Since there is no rerouting now traffic distribution is not done on Pods level but rather Nodes level. Example:

node1 -> pod1, pod4
node2 -> pod2
node3 -> pod3

With default configuration each pod will get 25% of new connections. With externalTrafficPolicy set to Local, each node will get 33% of new connections. Therefor pod1 and pod4 will get just 16,5% connections each while pod2 and pod3 will get 33% each.

### Recomendation of using this with Ingress only and then use X-Forwarded-For
Good solution if you need client IP information is to use it for Ingress, but not for other Services. By deploying ingress controller in Service with externalTrafficPolicy Local, your nginx proxy will see client IP. This means you can do whitelisting (source IP filters) in you Ingress definition. Traffic distribution problem is virtualy non existent because you typically run ingress on one or few nodes in cluster, but rarely you want more replicas then number of nodes.

You can specify this via Helm.

```
helm install --name ingress stable/nginx-ingress --set controller.service.externalTrafficPolicy=Local
```

Services that are behind proxy (for example frontend web server) will not suffer any potention disbalance in traffic distribution and while source IP is altered NGINX have inserted client IP information into X-Forwarded-For header that you can read in your application (to do logging for example).

## Upgrade
We will now do rolling upgrade of our application to new version. We are going to change deployment to use different container with v2 of our app.
```
kubectl apply -f deploymentWeb2.yaml
```

Watch pods being rolled
```
kubectl get pods -w
```

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
kubectl delete -f ingressWeb.yaml
kubectl delete -f serviceWebExtPublic.yaml
kubectl delete -f serviceWebExtPrivate.yaml
kubectl delete -f serviceWeb.yaml
kubectl delete -f podUbuntu.yaml
kubectl delete -f deploymentWeb1.yaml
kubectl delete -f deploymentWeb2.yaml
kubectl delete -f IIS.yaml
helm delete ingress --purge
kubectl delete secret mycert
az network dns record-set a delete -y -n mykubeapp -g shared-services -z azure.tomaskubica.cz
```
