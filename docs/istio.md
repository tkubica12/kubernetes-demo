- [Install Istio](#install-istio)
- [Accessing GUI](#accessing-gui)
- [Deploy with istio](#deploy-with-istio)
  - [Retry functionality](#retry-functionality)
  - [Copy traffic](#copy-traffic)
  - [Canary deployments](#canary-deployments)
  - [Managing access to services outside Istio with ServiceEntry](#managing-access-to-services-outside-istio-with-serviceentry)
  - [Managing access to services in Istio from outside with Gateway](#managing-access-to-services-in-istio-from-outside-with-gateway)
  - [Load-balancing algorithms](#load-balancing-algorithms)
  - [Circuit Breaker to protect from overloading](#circuit-breaker-to-protect-from-overloading)
    - [Service authentication and encryption](#service-authentication-and-encryption)
- [Clean up](#clean-up)

# Install Istio
First download istioctl.

```
cd ./istio
wget https://github.com/istio/istio/releases/download/1.4.0/istioctl-1.4.0-linux.tar.gz
tar -xvf istioctl-1.4.0-linux.tar.gz
sudo mv ./istioctl /usr/local/bin/
rm -rf istioctl-1.4.0-linux.tar.gz
```

Deploy Secrets to configure Grafana and Kiali username/password. File in this repo containers user/Azure12345678.

```bash
kubectl create namespace istio-system --save-config
kubectl apply -f grafanaSecret.yaml
kubectl apply -f kialiSecret.yaml
```

Deploy Istio using basic settings provided here in istioConfig.yaml.

```bash
istioctl manifest apply -f istioConfig.yaml
```

# Accessing GUI
Istioctl has deployed couple of GUI components, but those are not exposed to outside world by default (you may use Ingress to do so, but first make sure security is done right including authn/authz and https). To access only for AKS authenticated user we will use port-forward to pod running GUI. Istioctl provides shortcut for this commend.

```bash
istioctl dashboard grafana
istioctl dashboard prometheus
istioctl dashboard jaeger
istioctl dashboard kiali
istioctl dashboard envoy <pod-name>.<namespace>
```

# Deploy with istio
Let's now deploy our demo services with Istio Service Mesh.

```
kubectl label namespace default istio-injection=enabled
kubectl apply -f client.yaml
kubectl apply -f retryBackend.yaml
kubectl apply -f canary.yaml
```

## Retry functionality
First run client without any policy defined. We are using retry backend application that acceps failRate as argument and based on this percentage will either respond or crash the Pod. We will use 50% chance of getting no response and container crash.

```
export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")
kubectl exec $clientPod -c client -- curl -vs -m 10 retry-service?failRate=50
```

Now apply Istio policy to retry.

```
kubectl apply -f retryVirtualService.yaml
kubectl exec $clientPod -c client -- curl -vs -m 10 retry-service?failRate=50
```

As you can see you now get response even if your first request causes container to crash. This demonstrates retry functionality in Istio.

## Copy traffic
Sometimes it might be useful to get copy of traffic for troubleshooting for example to copy production API requests to beta service. We will deploy sniffer, which is simple image that runs tcpdump on port 80 and use Istio VirtualService to copy traffic between client and retry-service to sniffer.

```
kubectl apply -f sniffer.yaml
kubectl apply -f copyVirtualService.yaml

export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")
kubectl exec $clientPod -c client -- bash -c 'for x in {0..20}; do curl -s retry-service?failRate=1; done'
export snifferPod=$(kubectl get pods -l app=sniffer -o jsonpath="{.items[0].metadata.name}")
kubectl logs $snifferPod -c sniffer
```

## Canary deployments
Istio allows you to have better control over routing your traffic to different versions of services independently of infrastructure configuration (eg. number of pods with each service).

In our example we have 3 instances of v1 and 3 instances of v2 so we are 50% likely to hit v2.
```
kubectl exec $clientPod -c client -- bash -c 'while true; do curl -s myweb-service; echo; done'
```

Let's now configure Istio to send just 10% of traffic to v2. We will define DestinationRule where we configure two subsets (versions) identified by labels version: v1 and version: v2. Then we configure VirtualService that reference those two subsets and use 90 weight for v1 and 10 weight for v2. We should hit v2 only in 10% of requests.

```
kubectl apply -f canary10percent.yaml
kubectl exec $clientPod -c client -- bash -c 'while true; do curl -s myweb-service; echo; done'
```

What about serving v2 only for user with specific cookie? First let's remove our previous policy.

```
kubectl delete -f canary10percent.yaml
```

In order to achieve what we need to configure two rules in our VirtualService. First (v2) will have match statement that will check cookie for usertype-tester. If there is no match second (default) one (v1) will be used for ordinary users.

```
kubectl apply -f canaryCookie.yaml
kubectl exec $clientPod -c client -- curl -s myweb-service
kubectl exec $clientPod -c client -- curl -s --cookie "usertype=tester" myweb-service
```

## Managing access to services outside Istio with ServiceEntry
By default services in Istio mesh have no access to external world as we can test:

```
kubectl exec $clientPod -c client -- curl -vs httpbin.org/ip
```

Let's now define ServiceEntry for your Istio Service Mesh to allow access to httpbin.org and try again.

```
kubectl create -f serviceEntry.yaml
kubectl exec $clientPod -c client -- curl -vs httpbin.org/ip
```

## Managing access to services in Istio from outside with Gateway
As all traffic between services might be encrypted outside users cannot access services directly. In order to expose service such as web frontend to users outside of cluster we will use Istio Gateway. This is in principle similar to Kubernetes Ingress, but Istio provides specific implementation for entering services managed by Istio Service Mesh.

Deploy Gateway to make service accessible from outside of our cluster.
```
kubectl delete -f canary10percent.yaml
kubectl create -f gateway.yaml
```

Find out on which IP address Istio Ingress is running (Helm chart created service instanci of ty LoadBalancer so Azure provided external address to it).
```
export istioGwIp=$(kubectl get service istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Check access to service extrenally.
```
curl -i $istioGwIp -H "Host:myweb-service.domain.com"
```

In order to deploy URL paths and TLS certificates please refer to [this part of demo](docs/networking.md)

## Load-balancing algorithms
Istio comes with three load-balancing algorithms. Round robin, random and wighted least requests. Also if session stickiness is required consistent hash option is available based on some information from header such as Cookie or specific Header entry or via client source IP. Let's see couple of examples.

First we will deploy policy for round robin. We expect to see responses in sequences (one by one and again).
```
kubectl delete -f canary10percent.yaml
kubectl apply -f lbRoundRobin.yaml
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
```

Now we will configure LB algorithm random and test it.
```
kubectl apply -f lbRandom.yaml
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
```

Last example will be consistent hash. We will setup persistence based on header key Me. When key is not specified Istio to fall back to Random mode, when key is present we will get response from the same node for all subsequent calls (unless instance fails).
```
kubectl apply -f lbHeaderHash.yaml
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
while true; do kubectl exec $clientPod -c client -- curl -H "User: tomas" -s myweb-service; done
```

## Circuit Breaker to protect from overloading
To be updated for Istio 1.0.0

```
kubectl create -f <(istioctl kube-inject -i istio-system -f siege.yaml)
export siegePod=$(kubectl get pods -l app=siege -o jsonpath="{.items[0].metadata.name}")
kubectl exec $siegePod -c siege -- curl -vs -m 10 retry-service?failRate=50

kubectl exec -it $clientPod -c client -- bash -c 'while true; do curl -o /dev/null -w "%{http_code}..." -s myweb-service; sleep 0.1; done'

kubectl apply -f policyConnections.yaml
```

### Service authentication and encryption
TBD

# Clean up
```
kubectl delete -f .
istioctl manifest generate -f istioConfig.yaml | kubectl delete -f -
kubectl get secret --all-namespaces -o json | jq '.items[].metadata | ["kubectl delete secret -n", .namespace, .name] | join(" ")' -r | fgrep "istio." | xargs -t0 bash -c
```

