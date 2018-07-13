- [Creating service mesh with Istio](#creating-service-mesh-with-istio)
    - [Install istio](#install-istio)
        - [Download isctioctl command line](#download-isctioctl-command-line)
        - [Install Istion and related components](#install-istion-and-related-components)
        - [Accessing Grafana GUI and Zipkin](#accessing-grafana-gui-and-zipkin)
    - [Investigate services without Istio](#investigate-services-without-istio)
        - [No retry and no circuit breaker](#no-retry-and-no-circuit-breaker)
        - [Not enough features for canary release (A/B testing)](#not-enough-features-for-canary-release-ab-testing)
        - [Not enough control on egress](#not-enough-control-on-egress)
        - [Clean up](#clean-up)
    - [Deploy with istio](#deploy-with-istio)
        - [Test Retry functionality](#test-retry-functionality)
        - [Test canary deployments](#test-canary-deployments)
        - [Test Egress rule](#test-egress-rule)
        - [Test Ingress rule](#test-ingress-rule)
        - [Test load-balancing algorithms](#test-load-balancing-algorithms)
        - [Test Circuit Breaker to protect from overloading](#test-circuit-breaker-to-protect-from-overloading)
        - [Test service authentication and encryption](#test-service-authentication-and-encryption)
    - [Clean up](#clean-up)

**This section has not yet been updated for AKS**


# Creating service mesh with Istio

While Kubernetes provides container orchestration to expose services, provide balancing, rolling upgrades and service discovery, there are needs for connecting services together that require change in application code. Patterns like retry, circuit breaker, intelligent routing and service discovery, canary releases or end-to-end security with TLS encryption. Istio builds on top of Kubernetes and provides features for service mesh as addon leveraging side cars so there is no need to change application code to get those features.

## Install istio

For our demos we will work in istio directory.

```
cd ./istio
```

### Download isctioctl command line

First install Istio CLI

```
wget https://github.com/istio/istio/releases/download/0.4.0/istio-0.4.0-linux.tar.gz
tar -zxvf istio-0.4.0-linux.tar.gz
sudo mv istio-0.4.0/bin/istioctl /usr/local/bin/
rm -rf istio-0.4.0*
```

### Install Istion and related components

Istio comes with quite a few components and leverages other projects like Grafana or Zipkin to provide GUI or call tracing. Simplest way to install Istio is with Helm package.

```
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com

kubectl create namespace istio-system
helm install --name istio incubator/istio --namespace istio-system --devel --set auth.enabled=true --set istio.release=0.4.0
helm upgrade istio incubator/istio --reuse-values --set istio.install=true --devel

kubectl get pods --namespace istio-system
```

### Accessing Grafana GUI and Zipkin

Helm has deployed those services internally (not exposed via public IP - but you can change that if you like). To access services we can do port forwarding via kubectl from Kubernetes cluster to our system.

Create proxy to access Grafana dashboard:

```
export GRAFANA=$(kubectl get pods --namespace istio-system -l "component=istio-grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $GRAFANA 3000:3000 --namespace istio-system
```

You can now access Grafana at [http://127.0.0.1:3000/dashboard/db/istio-dashboard](http://127.0.0.1:3000/dashboard/db/istio-dashboard)

To access dynamic service map create this proxy:
```
export DOTVIZ=$(kubectl get pods --namespace istio-system -l "component=istio-servicegraph" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $DOTVIZ 8088:8088 --namespace istio-system
```

You can now access Grafana at [http://127.0.0.1:8088/dotviz](http://127.0.0.1:8088/dotviz)

## Investigate services without Istio
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
kubectl get pods -w
```

### Not enough features for canary release (A/B testing)
Kubernetes comes with built-in rolling upgrade capability for Deployments, check out other chapter for details:
[Using stateless app farms](docs/stateless.md)

Nevertheless sometimes you might want to have tighter control over rolling upgrade, for example keep both versions running for extended period of time for proper testing to be made or route traffic only for low percentage of users to new version or route beta users to new version. Closest you can get to with native Kubernetes is to use separate Deployments for each version while putting this under single service. Try it:

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

### Clean up
```
kubectl delete -f retryBackend.yaml
kubectl delete -f client.yaml
kubectl delete -f canary.yaml
```

## Deploy with istio
Let's now deploy our demo services with Istio Service Mesh.

```
kubectl create -f <(istioctl kube-inject -i istio-system -f client.yaml)
kubectl create -f <(istioctl kube-inject -i istio-system -f retryBackend.yaml)
kubectl create -f <(istioctl kube-inject -i istio-system -f canary.yaml)
```

### Test Retry functionality
First run client without any policy defined. There is 50% change of getting no response and container crash.

```
export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")
kubectl exec $clientPod -c client -- curl -vs -m 10 retry-service?failRate=50
```

Now apply Istio policy to retry.

```
kubectl apply -f policyRetry.yaml
kubectl exec $clientPod -c client -- curl -vs -m 10 retry-service?failRate=50
```

As you can see you now get response even if your first request causes container to crash. This demonstrates retry functionality in Istio.

### Test canary deployments
Istio allows you to have better control over routing your traffic to different versions of services independently of infrastructure configuration (eg. number of pods with each service).

In our example we have 3 instances of v1 and 3 instances of v2 so we are 50% likely to hit v2.
```
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
```

Let's now configure routing policy to send just 10% of traffic to v2.
```
kubectl apply -f policyCanary10percent.yaml
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
```

What about serving v2 only for user with specific cookie? First let's remove our previous policy.
```
kubectl delete -f policyCanary10percent.yaml
```

In order to achieve what we need we will deploy two Istio route rules. First one with default preference (0, which means will be evaluated last) to route all traffic to v1. Also we will deploy higher preference route rule that matches our cookie and routes traffic to v2.
```
kubectl apply -f policyCanaryCookie.yaml
kubectl exec $clientPod -c client -- curl -s myweb-service
kubectl exec $clientPod -c client -- curl -s --cookie "usertype=tester" myweb-service
```

### Test Egress rule
By default services in Istio mesh have no access to external world as we can test:

```
kubectl exec $clientPod -c client -- curl -vs httpbin.org/ip
< HTTP/1.1 404 Not Found
< date: Fri, 29 Dec 2017 09:04:37 GMT
* Server envoy is not blacklisted
< server: envoy
< content-length: 0
```

Let's now define egress policy for your Istio Service Mesh to allow access to httpbin.org and try again.

```
kubectl create -f egressRule.yaml
kubectl exec $clientPod -c client -- curl -vs httpbin.org/ip
* Hostname was NOT found in DNS cache
*   Trying 23.21.206.136...
* Connected to httpbin.org (23.21.206.136) port 80 (#0)
> GET /ip HTTP/1.1
> User-Agent: curl/7.35.0
> Host: httpbin.org
> Accept: */*
>
< HTTP/1.1 200 OK
* Server envoy is not blacklisted
< server: envoy
< date: Tue, 02 Jan 2018 13:51:11 GMT
< content-type: application/json
< access-control-allow-origin: *
< access-control-allow-credentials: true
< x-powered-by: Flask
< x-processed-time: 0.000565052032471
< content-length: 33
< via: 1.1 vegur
< x-envoy-upstream-service-time: 188
<
{ [data not shown]
* Connection #0 to host httpbin.org left intact

```

### Test Ingress rule
As all traffic between services is encrypted outside users cannot access services directly. In order to expose service such as web frontend to users outside of cluster we will use Kubernetes Ingress object. Istio comes with special implementation of Ingress that handles traffic entering Service Mesh.

Deploy Ingress to make service accessible from outside of our cluster.
```
kubectl create -f ingressRule.yaml
```

Find out on which IP address Istio Ingress is running (Helm chart created service instanci of ty LoadBalancer so Azure provided external address to it).
```
export ingressIP=$(kubectl get service istio-ingress --namespace istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

```

Check access to service extrenally.
```
curl -i $ingressIP
```

In order to deploy URL paths and TLS certificates please refer to [this part of demo](docs/stateless.md)

### Test load-balancing algorithms
Istio comes with three load-balancing algorithms. Round robin, random and least connections. Let's test this.

First we will deploy policy for round robin. We expect to see responses in sequences (one by one and again).
```
kubectl apply -f policyLbRoundRobin.yaml
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
```

Now we will configure LB algorithm random and test it.
```
kubectl apply -f policyLbRandom.yaml
while true; do kubectl exec $clientPod -c client -- curl -s myweb-service; done
```


### Test Circuit Breaker to protect from overloading
TBD

```
kubectl create -f <(istioctl kube-inject -i istio-system -f siege.yaml)
export siegePod=$(kubectl get pods -l app=siege -o jsonpath="{.items[0].metadata.name}")
kubectl exec $siegePod -c siege -- curl -vs -m 10 retry-service?failRate=50

kubectl exec -it $clientPod -c client -- bash -c 'while true; do curl -o /dev/null -w "%{http_code}..." -s myweb-service; sleep 0.1; done'

kubectl apply -f policyConnections.yaml
```

### Test service authentication and encryption
TBD

## Clean up
```
kubectl delete -f client.yaml
kubectl delete -f retryBackend.yaml
kubectl delete -f canary.yaml
kubectl delete -f policyRetry.yaml
kubectl delete -f egressRule.yaml
kubectl delete -f policyCanary10percent.yaml
kubectl delete -f policyCanaryCookie.yaml
kubectl delete -f ingressRule.yaml
helm delete istio --purge
```

