# Basic introduction to world of containers and cloud native

## WebApp with containers as PaaS

Create WebApp for container, Linux version, Python 3.8 PaaS environment

Configure Deploment via local Git, remote build

Clone to PROD folder

Copy files requirements.txt and application.py from src folder, remove app.run statement

Check app is running

Create TEST slot, configure deployment via local Git, remote build a repeat steps to deliver code, but change message to v2.

Test slot swap, A/B testing, canary

## Building custom container and using in WebApp
Create container registry and build container

```bash
az group create -n acr -l westeurope
az acr create -n mojeskvelekontejnery -g acr --sku Standard --admin-enabled
az acr build -r mojeskvelekontejnery --image appka:v1 .
```

Change application code to v2 and build it.

```bash
az acr build -r mojeskvelekontejnery --image appka:v2 .
```

Use GUI to create WebApp with custom container.

## AKS basics
Add AKS identity to ACR with AcrPull role.

Basic Pod operations

```bash
cd kube
kubectl create namespace intro
kubens intro
kubectl apply -f podApp.yaml
kubectl get pods -w
kubectl describe pod appka
kubectl port-forward pod/appka 54321:8080
kubectl logs appka
kubectl delete pod appka
```

Deployment controller

```bash
kubectl apply -f deployAppV1.yaml
kubectl get deploy,rs,pods
kubectl delete pod appka-xxxx
kubectl get pods --show-labels  
kubectl get pods -l app=appka
kubectl get pods -L app
kubectl get rs
kubectl describe rs appka-xxx
kubectl edit pod appka-xxx   # change label to something else
kubectl get pods --show-labels
```

Service (L4 balancing and DNS discovery)

```bash
kubectl apply -f podUbuntu.yaml
kubectl apply -f serviceApp.yaml
kubectl get service appka

# Internal test
kubectl exec -ti ubuntu -- /bin/bash
curl appka

# External test
$extPublicIP = $(kubectl get service appka -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while true; do curl $extPublicIP; echo; done
```

Rolling upgrade

```bash
kubectl apply -f deployAppV2.yaml
```

Ingress - expose via L7 balancer and WAF in Azure

```bash
kubectl apply -f ingressApp.yaml
```

Windows nodes - IIS app at iis.cloud.tomaskubica.in

## Management
Look at Application Insights map and tracing.

AKS monitoring. 

Cluster operations.

Azure Policy and security.


## Infrastructure as Code
Check Terraform template to deploy AKS, database, Service Bus, idetities and other components

## Basic demo with state
Check todo applicaiton in default namespace.

Look at Secrets, Config Map

## Building on top of Kubernetes

### DAPR + KEDA

```bash
# In one window generate messages via DAPR sidecar to Service Bus
kubectl exec -ti nodea-0 -n dapr -- python /home/user/sendMessagesToServiceBus.py

# In second window watch containers being created and using DAPR to injest messages
kubectl get pods -n dapr -w
```

### Flagger for canary releasing