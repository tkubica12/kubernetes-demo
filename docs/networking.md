# Advanced networking with Ingress (L7 proxy) and network policy
We have seen a lot of networking already: internal ballancing and service discovery, external balancing with automatic integration to Azure Load Balancer with public IP, communication between pods in container etc. In this section we will focus on some other aspects namely networking policy.

- [Advanced networking with Ingress (L7 proxy) and network policy](#advanced-networking-with-ingress-l7-proxy-and-network-policy)
    - [Create externally accessible service with L7 proxy (Kubernetes ingress)](#create-externally-accessible-service-with-l7-proxy-kubernetes-ingress)
        - [Make sure Helm is installed](#make-sure-helm-is-installed)
        - [Deploy nginx ingress](#deploy-nginx-ingress)
        - [Prepare certificate and store it as Kubernetes secret](#prepare-certificate-and-store-it-as-kubernetes-secret)
        - [Create DNS record](#create-dns-record)
        - [Create ingress for our service](#create-ingress-for-our-service)
        - [Autoenroll Let's encrypt certificates with Kube-lego](#autoenroll-lets-encrypt-certificates-with-kube-lego)
        - [Test](#test)
        - [Source IP whitelisting](#source-ip-whitelisting)
        - [Cleanup](#cleanup)
    - [Network policy with Calico](#network-policy-with-calico)
        - [I will reference my kubectl config pointing to Calico-enabled cluster](#i-will-reference-my-kubectl-config-pointing-to-calico-enabled-cluster)
        - [Create web and db pod](#create-web-and-db-pod)
        - [Make sure web can both ping and mysql to db pod](#make-sure-web-can-both-ping-and-mysql-to-db-pod)
        - [Create network policy to allow mysql communication only](#create-network-policy-to-allow-mysql-communication-only)

## Create externally accessible service with L7 proxy (Kubernetes ingress)
In case we want L7 balancing, URL routing and SSL acceleration we need to use ingress controler with NGINX implementation. This will deploy http proxy into Kubernetes accessible via external IP (leveraging Azure LB and Azure DNS). Proxy then handles traffic routing to internal services in cluster and provides SSL acceleration.

### Make sure Helm is installed
Please refer to this chapter for installing Helm:

[Package applications with Helm](docs/helm.md)

### Deploy nginx ingress
First we need to deploy L7 proxy that will work as Kubernetes Ingress balancer. We are using helm to easily install complete package (more on Helm later in this demo).

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
We need to register nginx-ingress public IP address with DNS server. In this demo we use my existing Azure DNS.

```
export ingressIP=$(kubectl get service ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

az network dns record-set a add-record -a $ingressIP -n mykubeapp -g shared-services -z azure.tomaskubica.cz
```

### Create ingress for our service
We are ready to go. Let's create ingress service that will reference (expose) internal service we have created previously.

```
kubectl create -f ingressWeb.yaml
```

### Autoenroll Let's encrypt certificates with Kube-lego
As we have seen you can import any certificate to Ingress you prepare beforehand, but doing so with Let's encrypt certification authority require you to repeat this process manualy every three months. You might want to enroll and re-enroll certificates automatically. This is what Kube-lego can handle.

Use helm to deploy kube-lego and make sure to provide your valid email address.
```
helm install stable/kube-lego --namespace kube-system --name kube-lego --set config.LEGO_EMAIL=YOUR_EMAIL,config.LEGO_URL=https://acme-v01.api.letsencrypt.org/directory
```

We need to add annotation to our Ingress definition to request kube-lego to enroll Let's encrypt certificates.
```
kubectl apply -f ingressWebLego.yaml
```

Test your site now. As we have valid public certificate we do not have to use -k option.
```
curl -v https://mykubeapp.azure.tomaskubica.cz
```

### Test
Access app at https://mykubeapp.azure.tomaskubica.cz/myweb

Because certificate is self-signed (not trusted) use this to test and check certificate:
```
curl -vk https://mykubeapp.azure.tomaskubica.cz/myweb
```

### Source IP whitelisting
You can specify this via Helm.

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

### Cleanup

```
kubectl delete -f ingressWeb.yaml
helm delete ingress --purge
kubectl delete secret mycert
az network dns record-set a delete -y -n mykubeapp -g shared-services -z azure.tomaskubica.cz
```

## Network policy with Calico
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