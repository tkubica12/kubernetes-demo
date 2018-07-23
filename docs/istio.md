- [Creating service mesh with Istio](#creating-service-mesh-with-istio)
    - [Investigate services without Istio (Why Istio)](#investigate-services-without-istio-why-istio)
        - [No retry and no circuit breaker](#no-retry-and-no-circuit-breaker)
        - [Not enough features for canary release (A/B testing)](#not-enough-features-for-canary-release-ab-testing)
        - [Not enough control on egress](#not-enough-control-on-egress)
        - [Other issues](#other-issues)
        - [Clean up](#clean-up)
    - [Install Istio](#install-istio)
    - [Accessing Grafana GUI and Zipkin](#accessing-grafana-gui-and-zipkin)
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

**This section has not yet been updated for AKS**

# Creating service mesh with Istio

While Kubernetes provides container orchestration to expose services, balancing, rolling upgrades and service discovery, there are needs for connecting services together that require change in application code. Patterns like retry, circuit breaker, intelligent routing and service discovery, canary releases or end-to-end security with TLS encryption. Istio builds on top of Kubernetes and provides features for service mesh as addon leveraging side cars so there is no need to change application code to get those features.

## Investigate services without Istio (Why Istio)
First let's deploy simple services and investigate issues.

### No retry and no circuit breaker
Deploy retry backend and client. Source for retry-backend is in retry-demo-backend folder of this repo. It is simple Python app packaged in container that can fail at rate you request in percentage. It can fail by immediately returning 503 or you can request hardCrash when application will hang for 20 seconds and that exit with non-zero error code (this simulates code getting stuck and then terminate main container process).

```
kubectl create -f retryBackend.yaml
kubectl create -f client.yaml

export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")
```

Now we will call service with failure rate set to 50%. As our client code has no retry functionality it will timeout with 50% probability causing bad user experience.

````
kubectl exec $clientPod -- curl -vs -m 2 retry-service?failRate=50
````

Also there is no circuit breaker. It might happen that our service has bug that makes it crash. Kubernetes restart container automatically, but each crash causes delay and waste resources. Our clients will always have to wait for timeout and keep containers crashing over and over again causing bad user experience. There is no circuit breaker that would return 503 immediately when the service is down so client can react on that rather than always waiting for timeout.

Check how containers are being restarted.

```
kubectl exec $clientPod -- curl -vs -m 2 retry-service?failRate=99
kubectl get pods -w
```

### Not enough features for canary release (A/B testing)
Kubernetes comes with built-in rolling upgrade capability for Deployments, check out other chapter for details:
[Deploying apps with Pods, Deployments and Services](docs/apps.md)

Nevertheless sometimes you might want to have tighter control over rolling upgrade, for example keep both versions running for extended period of time for proper testing to be made or route traffic only for low percentage of users to new version or route beta users to new version. Closest you can get to with native Kubernetes is to use separate Deployments for each version while putting this under single service as we discussed in referenced chapter also. Try it:

```
kubectl create -f canary.yaml
kubectl exec $clientPod -c client -- curl -s myweb-service
```

There are two issues with this approach:
* Percentage on vNext traffic is bounded to number of replicas to run. For example to serve vNext to just 1% of requests (to carefully monitor potential impact) one needs to run 99 replicas of vCurrent a 1 replica of vNext
* Scaling of vCurrent a vNext is separated. For example when autoscaling changes number of vCurrent instances, percentage of vNext traffic changes
* You might want more intelligent routing to vNext for example to target your beta users. Typically you would use special header to identify beta user and route traffic to vNext for those

### Not enough control on egress
In order to control egress traffic in your cluster you can leverage Kubernetes Network Policy API with Calico implementation as an example. But even then you can control your egress only on L4 by defining destination IP address or range. If your external service is using some form of DNS-based geo balancing endpoint IP address might change over time. You would rather need to have control on higher level by defining FQDN.

### Other issues
There are more things that need to be solved in code. For example mutual TLS authentication between services or complex service mesh monitoring.

### Clean up
```
kubectl delete -f retryBackend.yaml
kubectl delete -f client.yaml
kubectl delete -f canary.yaml
```

## Install Istio

For our demos we will work in istio directory.

```
cd ./istio
```

Download Istio package, install CLI component and use Helm to deploy server-side components. Note that Istio can automatically inject side-cars to your Pods, but that requires special setting when creating cluster not supported by AKS (but you can get it with ACS-engine). In our example we will use manual injection which also give us little more

```
wget https://github.com/istio/istio/releases/download/1.0.0-snapshot.1/istio-1.0.0-snapshot.1-linux.tar.gz
tar -zxvf istio-1.0.0-snapshot.1-linux.tar.gz
sudo mv istio-1.0.0-snapshot.1/bin/istioctl /usr/local/bin/
helm install ./istio-1.0.0-snapshot.1/install/kubernetes/helm/istio \
    --name istio \
    --namespace istio-system \
    --set sidecarInjectorWebhook.enabled=false,grafana.enabled=true,servicegraph.enabled=true,tracing.enabled=true
rm -rf istio-1.0.0*
```

## Accessing Grafana GUI and Zipkin
Helm has deployed those services internally (not exposed via public IP - but you can change that if you like). To access services we can do port forwarding via kubectl from Kubernetes cluster to our system.

Create proxy to access **Grafana dashboard**:

```
export GRAFANA=$(kubectl get pods --namespace istio-system -l "app=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $GRAFANA 3000:3000 --namespace istio-system
```

You can now access Grafana at http://127.0.0.1:3000/dashboard/db/istio-dashboard

To access dynamic **service map** create this proxy:

```
export JAEGER=$(kubectl get pods --namespace istio-system -l "app=jaeger" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $JAEGER 30001:16686 --namespace istio-system
```

You can now access service map at http://127.0.0.1:30001

To access **Jaeger tracing** create this proxy:

```
export SERVICEGRAPH=$(kubectl get pods --namespace istio-system -l "app=servicegraph" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $SERVICEGRAPH 8088:8088 --namespace istio-system
```

You can now access Jaeger tracing at http://127.0.0.1:8088/force/forcegraph.html

## Deploy with istio
Let's now deploy our demo services with Istio Service Mesh.

```
kubectl create -f <(istioctl kube-inject -i istio-system -f client.yaml)
kubectl create -f <(istioctl kube-inject -i istio-system -f retryBackend.yaml)
kubectl create -f <(istioctl kube-inject -i istio-system -f canary.yaml)
```

### Retry functionality
First run client without any policy defined. There is 50% change of getting no response and container crash.

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

### Copy traffic
Sometimes it might be useful to get copy of traffic for troubleshooting for example to copy production API requests to beta service. 

```
kubectl create -f <(istioctl kube-inject -i istio-system -f sniffer.yaml)
kubectl apply -f copyVirtualService.yaml

export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")
kubectl exec $clientPod -c client -- bash -c 'for x in {0..20}; do curl -s retry-service?failRate=1; done'
export snifferPod=$(kubectl get pods -l app=sniffer -o jsonpath="{.items[0].metadata.name}")
kubectl logs $snifferPod
```

### Canary deployments
Istio allows you to have better control over routing your traffic to different versions of services independently of infrastructure configuration (eg. number of pods with each service).

In our example we have 3 instances of v1 and 3 instances of v2 so we are 50% likely to hit v2.
```
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
```

Let's now configure Istio to send just 10% of traffic to v2. We will define DestinationRule where we configure two subsets (versions) identified by labels version: v1 and version: v2. Then we configure VirtualService that reference those two subsets and use 90 weight for v1 and 10 weight for v2. We should hit v2 only in 10% of requests.

```
kubectl apply -f canary10percent.yaml
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
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

### Managing access to services outside Istio with ServiceEntry
By default services in Istio mesh have no access to external world as we can test:

```
kubectl exec $clientPod -c client -- curl -vs httpbin.org/ip
```

Let's now define ServiceEntry for your Istio Service Mesh to allow access to httpbin.org and try again.

```
kubectl create -f serviceEntry.yaml
kubectl exec $clientPod -c client -- curl -vs httpbin.org/ip
```

### Managing access to services in Istio from outside with Gateway
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

### Load-balancing algorithms
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


### Circuit Breaker to protect from overloading
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

## Clean up
```
kubectl delete -f .
helm delete istio --purge
```

