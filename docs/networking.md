# Advanced networking with Ingress (L7 proxy) and network policy
We have seen a lot of networking already: internal ballancing and service discovery, external balancing with automatic integration to Azure Load Balancer with public IP, communication between pods in container etc. In this section we will focus on some other aspects namely networking policy.

- [Advanced networking with Ingress (L7 proxy) and network policy](#advanced-networking-with-ingress-l7-proxy-and-network-policy)
- [Externally accessible service with L7 proxy (Kubernetes Ingress)](#externally-accessible-service-with-l7-proxy-kubernetes-ingress)
  - [Basic Ingress](#basic-ingress)
    - [Make sure Helm is installed](#make-sure-helm-is-installed)
    - [Deploy nginx ingress](#deploy-nginx-ingress)
    - [Prepare certificate and store it as Kubernetes secret](#prepare-certificate-and-store-it-as-kubernetes-secret)
    - [Create DNS record](#create-dns-record)
    - [Create ingress for our service](#create-ingress-for-our-service)
    - [Autoenroll Let's encrypt certificates with cert-manager](#autoenroll-lets-encrypt-certificates-with-cert-manager)
  - [Advanced Ingress configuration](#advanced-ingress-configuration)
    - [Source IP whitelisting](#source-ip-whitelisting)
    - [Sticky session](#sticky-session)
    - [Custom errors](#custom-errors)
    - [Rate limiting](#rate-limiting)
    - [Basic authentication](#basic-authentication)
    - [External authentication using OAuth 2.0 and Azure Active Directory](#external-authentication-using-oauth-20-and-azure-active-directory)
  - [Cleanup](#cleanup)
- [Network policy with Calico](#network-policy-with-calico)
    - [I will reference my kubectl config pointing to Calico-enabled cluster](#i-will-reference-my-kubectl-config-pointing-to-calico-enabled-cluster)
    - [Create web and db pod](#create-web-and-db-pod)
    - [Make sure web can both ping and mysql to db pod](#make-sure-web-can-both-ping-and-mysql-to-db-pod)
    - [Create network policy to allow mysql communication only](#create-network-policy-to-allow-mysql-communication-only)

# Externally accessible service with L7 proxy (Kubernetes Ingress)
In case we want L7 balancing, URL routing and SSL acceleration we need to use ingress controler with NGINX implementation. This will deploy http proxy into Kubernetes accessible via external IP (leveraging Azure LB and Azure DNS). Proxy then handles traffic routing to internal services in cluster and provides SSL acceleration.

## Basic Ingress
In this section we will install and explore basic Ingress services using NGINX implementation including L7 path selections, TLS termination and automatic certificates management.

### Make sure Helm is installed
Please refer to this chapter for installing Helm:

[Package applications with Helm](docs/helm.md)

### Deploy nginx ingress
First we need to deploy L7 proxy that will work as Kubernetes Ingress balancer. We are using Helm to easily install complete package.

```
helm install --name ingress stable/nginx-ingress --set rbac.create=true
```

### Prepare certificate and store it as Kubernetes secret 
We will want to use TLS encryption (HTTPS). For demo purposes we will now create self-signed certificate.

```
openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt -days 365 -nodes -subj '/CN=mykubeapp.azure.tomaskubica.cz'

kubectl create secret tls mycert --key tls.key --cert tls.crt

rm tls.key
rm tls.crt
```

### Create DNS record
We need to register nginx-ingress public IP address with DNS server. In this demo we use my existing Azure DNS. Also we will want to add wildcard DNS record so we can expose for example portal.mykubeapp.azure.tomaskubica.cz without need to create specific record for portal.

```
export ingressIP=$(kubectl get service ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

az network dns record-set a add-record -a $ingressIP -n mykubeapp -g shared-services -z azure.tomaskubica.cz

az network dns record-set a add-record -a $ingressIP -n "*.mykubeapp" -g shared-services -z azure.tomaskubica.cz
```

### Create ingress for our service
We are ready to go. Let's create ingress service that will reference (expose) internal service. We will expose application on two paths - mykubeapp.azure.tomaskubica.cz and portal.mykubeapp.azure.tomaskubica.cz.

```
kubectl create -f deploymentWeb1.yaml
kubectl create -f serviceWeb.yaml
kubectl create -f ingressWeb.yaml
```

Test it out and make sure our certificate is presented for mykubeapp.azure.tomaskubica.cz. We have not specified certificate for portal.mykubeapp.azure.tomaskubica.cz so we will see default NGINX certificate. Also note that when accessing via http Ingress will do redirect to https.

```
curl -v mykubeapp.azure.tomaskubica.cz
curl -kv https://mykubeapp.azure.tomaskubica.cz
curl -kv https://portal.mykubeapp.azure.tomaskubica.cz
```

### Autoenroll Let's encrypt certificates with cert-manager

As we have seen you can import any certificate to Ingress you prepare beforehand, but doing so with Let's encrypt certification authority require you to repeat this process manualy every three months. You might want to enroll and re-enroll certificates automatically. This is what cert-manager can handle.

Use helm to deploy cert-manager and configure for Let's encrypt provider.

```
helm install stable/cert-manager --name cert-manager \
  --set ingressShim.defaultIssuerName=letsencrypt-prod \
  --set ingressShim.defaultIssuerKind=ClusterIssuer
```

Now we need to deploy certificate issuer. Please modify yaml file to include your email address.
```
kubectl apply -f certIssuer.yaml
```

At this point we are ready to create certificate for our domain. We will store it in Secret.
```
kubectl apply -f cert.yaml
kubectl describe secret/letsencrypt-prod
```

We need to add annotation to our Ingress definition to request kube-lego to enroll Let's encrypt certificates.
```
kubectl delete -f ingressWeb.yaml
kubectl apply -f ingressWebCertmanager.yaml
```

Test your site now. As we have valid public certificate we do not have to use -k option.
```
curl -v https://mykubeapp.azure.tomaskubica.cz
```

## Advanced Ingress configuration
We have covered what is currently available as part of Kubernetes Ingress object definition. NGINX implementation does offer more capabilities that can be configured using annotations.

### Source IP whitelisting
There are scenarios when access to your application needs to be limited based on client source IP. In order get this working we need to keep client source IP when traffic reaches Ingress controller (which runs as Kubernetes Service). We need to deploy this Service with externalTrafficPolicy local, which we can do when using helm install.

```
helm install --name ingress stable/nginx-ingress --set controller.service.externalTrafficPolicy=Local
```

Then you can use whitelisting in your ingress definitions:

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: whitelist
annotations:
  ingress.kubernetes.io/whitelist-source-range: "1.1.1.1/24,2.2.2.2/32"
```

Services that are behind proxy (for example frontend web server) will not suffer any potention disbalance in traffic distribution and while source IP is altered NGINX have inserted client IP information into X-Forwarded-For header that you can read in your application (to do logging for example).

### Sticky session

Cloud-native applications that follow design principles such as 12 factor do not hold any session state in memory, but rather externally in service such as Azure Redis. With that client can contact any instance every time as session state (such as buying basket) is loaded from Redis. More traditional applications might not be designed this way or additional latency is not acceptable. In that case state can be hold on client and sent to instance with every request, but that requires client side to implement that and store and transfer that in secure manner. Nevertheless stateless apps do scale better as new instances being created are immediately avaliable for all clients, not just for new sessions.

But if application architecture requires it you can implement session persistence on Ingress level so all client requests are handled by the same instance (Pod) every time (unless there is failure). With plain Services you are limited to Client IP persistence only which works well for individual end customers, but not when a lot of clients sit behind single IP (such as company router). In that case it is better to handle this persistence using cookie and NGINX Ingress does implement that.

Let's deploy Ingress and use annotations to turn on cookie session persistence.
```
kubectl apply -f ingressWebCookiePersistence.yaml
```

If we ignore cookie we may reach different instance for every request.
```
for i in {1..10}; do curl https://mykubeapp.azure.tomaskubica.cz; done
```

Let's read headers we get back from Ingress.
```
curl -I https://mykubeapp.azure.tomaskubica.cz
```

We will no pass this cookie in our request to get always to the same instance.
```
for i in {1..10}; do curl --cookie SESSIONCOOKIE=25deff81b2b2b39a97e454d971daff6160b04d24 https://mykubeapp.azure.tomaskubica.cz; done
```

### Custom errors

TBD

### Rate limiting

Are you afraid misbehaving clients can overload your services? To protect yourself from large-scale DDoS attacks you can deploy Azure DDoS Protection Standard SKU in your VNET. Another level of protection can be implemented on Ingress level as basic rate limit of request from single source IP. Note that by default Client IP is not visible for Ingress so you could do just some very high level overall rate limit (see proper section in this document to learn how to make Client IP visible for Ingress).

To easily demonstrate this let's deploy Ingress with limit of 5 requests per minute. There are also annotations to limit requests per second or limit concurent connections from single source IP. You may also whitelist some source IP ranges so rate limit do not apply for those with nginx.ingress.kubernetes.io/limit-whitelist.

```
kubectl apply -f ingressWebRateLimit.yaml
for i in {1..50}; do curl https://mykubeapp.azure.tomaskubica.cz; done
```

### Basic authentication

TBD

### External authentication using OAuth 2.0 and Azure Active Directory

TBD

## Cleanup

```
kubectl delete -f ingressWeb.yaml
helm delete ingress --purge
helm delete cert-manager --purge
kubectl delete secret mycert
kubectl delete -f cert.yaml
kubectl delete -f certIssuer.yaml
az network dns record-set a delete -y -n mykubeapp -g shared-services -z azure.tomaskubica.cz
az network dns record-set a delete -y -n "*.mykubeapp" -g shared-services -z azure.tomaskubica.cz
```

# Network policy with Calico

** Currenlty Calico is not available for AKS, only for ACS-engine **

Calico is plugin that implements Kubernetes network policy, namely microsegmentation (L4 filtering between pods). In this demo we will create Web and DB and provide strict policy what and how can communicate.

### I will reference my kubectl config pointing to Calico-enabled cluster
```
kubectx mykubecalico
```

### Create web and db pod
```
kubectl create -f podNetWeb.yaml
kubectl create -f podNetDB.yaml
kubectl exec net-web ip a
kubectl exec net-db ip a
```

### Make sure web can both ping and mysql to db pod
```
export dbip=$(kubectl get pod net-db -o json | jq -r '.status.podIP')
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```

### Create network policy to allow mysql communication only
```
kubectl create -f networkPolicy.yaml
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```