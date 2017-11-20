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
```
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.7.2-linux-amd64.tar.gz
tar -zxvf helm-v2.7.2-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin
rm -rf linux-amd64/
helm init
```

### Deploy nginx ingress
First we need to deploy L7 proxy that will work as Kubernetes Ingress balancer. We are using helm to easily install complete package (more on Helm later in this demo).

If you run on cluster with no RBAC (currently AKS) use this:
```
helm install --name ingress stable/nginx-ingress -f nginx-ingress-values.yaml
```

If you run on cluster with no RBAC (our mixed ACS cluster example) use this:
```
helm install --name ingress stable/nginx-ingress -f nginx-ingress-values-rbac.yaml
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
