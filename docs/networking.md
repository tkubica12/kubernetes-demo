# Advanced networking
We have seen a lot of networking already: internal balancing and service discovery, external balancing with automatic integration to Azure Load Balancer with public IP, communication between pods in container etc. In this section we will focus on some advanced concepts such as L7 balancing/routing with Ingress, filtering traffic with Network Policy and using Service Mesh as inteligent routing layer between microservices.

- [Advanced networking](#advanced-networking)
- [Externally accessible service with L7 proxy (Kubernetes Ingress)](#externally-accessible-service-with-l7-proxy-kubernetes-ingress)
- [Network Policy](#network-policy)
- [Service Mesh](#service-mesh)
  - [Implementations](#implementations)
  - [Why Service Mesh?](#why-service-mesh)
    - [No retry and no circuit breaker](#no-retry-and-no-circuit-breaker)
    - [Not enough features for canary release (A/B testing)](#not-enough-features-for-canary-release-ab-testing)
    - [Not enough control on egress](#not-enough-control-on-egress)
    - [Other issues](#other-issues)
    - [Clean up](#clean-up)
- [Automated canary releases with Flagger and Ingress or Service Mesh](#automated-canary-releases-with-flagger-and-ingress-or-service-mesh)
  - [Flagger with NGINX Ingress](#flagger-with-nginx-ingress)
    - [Installation](#installation)
    - [Canary](#canary)
    - [A/B testing](#ab-testing)
  - [Flagger with Istio](#flagger-with-istio)
    - [Install Istio](#install-istio)
    - [Install Flagger](#install-flagger)
    - [Canary release](#canary-release)
    - [A/B testing](#ab-testing-1)
    - [Clean uo](#clean-uo)

# Externally accessible service with L7 proxy (Kubernetes Ingress)
In case we want L7 balancing, URL routing and SSL acceleration we can use Ingress controler. There are many implementations such as NGINX ingress (kind of "default" solution), Traefik or controller for Azure Application Gateway.

[See more documentation and labs on Ingress](./ingress.md)

# Network Policy
Kubernetes Network Policy can be used for microsegmentation (L4 filtering between pods). You can create network isolation between namespaces or use Pod labels to define what services can talk to others and on what ports.

[See more documentation and labs on Network Policy](./networkpolicy.md)

# Service Mesh
Service Mesh technologies can bring intelligent network behavior to platform so application developers can leverage that without building specific support in their code. Most typical areas covered are:
- Traffic split - ability to decide where to route traffic based on percentage, headers or other conditions to enable canary releases or A/B testing
- Traffic control - implementing patterns like retry, circuit breaker, rate limit or mutual TLS authentication and encryption
- Visibility - ability to capture traffic statics and logging

## Implementations
- [Istio](istio.md)
- [Linkerd](linkerd.md)

TBD:
- Service Mesh Interface
- Consul Connect

## Why Service Mesh?
First let's deploy simple services and investigate limitations of plain Kubernetes.

While Kubernetes provides container orchestration to expose services, balancing, rolling upgrades and service discovery, there are needs for connecting services together that require change in application code. Patterns like retry, circuit breaker, intelligent routing and service discovery, canary releases or end-to-end security with TLS encryption. Istio builds on top of Kubernetes and provides features for service mesh as addon leveraging side cars so there is no need to change application code to get those features.

First let's deploy simple services and investigate limitations of plain Kubernetes and why Service Mesh can help.

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

There are few issues with this approach:
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

# Automated canary releases with Flagger and Ingress or Service Mesh
You might want to run current and next version of your application component for some period of time to slowly introduce change, monitor telemetry, gather feedback and only if no issues are found in production continue with deployment. There are couple ways to achieve this:
- If your app is mostly about REST APIs access from frontend you might use features of API management solution such as Azure API Management. Non-breaking changes can be introduced with concept of revision a beta frontend can explicitely ask for different than default revision. Breaking changes can be rolled using concept of versioning. APIM is responsible for routing traffic to correct instance of the service.
- You can use Ingress to implement traffic split based on probability, cookie or other methods. This is useful for traffic between consumers outside of Kubernetes (eg. frontend) and inside.
- Service Mesh can implement intelligent routing and traffic split based on probability or in some cases more complicated rules based on header etc. This is possible even for communication of services inside cluster.
- You are looking for different scenario then production, eg. testing new version of microservice in UAT environment. This is solved with Azure DevSpaces

We might distinguish three slightly different scenarios:
- Canary release as sending some percentage of traffic to newer version
- A/B testing as sending some users to different version, eg. based on header or cookie (beta testers, certain users)
- Green/Blue deployment as provisioning new version while keep existing one running and "releasing" by switching traffic to newer version

In this demo we will focus on Ingress and Service Mesh options and use Flagger to automate graduating next version based on telemetry and other patterns.

## Flagger with NGINX Ingress

**Note: as of NGINX Ingress version 0.26.1 canary metrics are not reported to Prometheus so Flagger cannot use default request-success-rate metrics**

### Installation

Install NGINX Ingress controller and enable telemetry export via Prometheus.

```bash
helm upgrade -i nginx-ingress stable/nginx-ingress \
--set controller.stats.enabled=true \
--set controller.metrics.enabled=true \
--set controller.podAnnotations."prometheus\.io/scrape"=true \
--set controller.podAnnotations."prometheus\.io/port"=10254
```

Install Flagger

```bash
# Add Flagger repo
helm repo add flagger https://flagger.app

# Install Flagger
helm upgrade -i flagger flagger/flagger \
--set prometheus.install=true \
--set meshProvider=nginx

# Optionaly add webhook to Microsoft Teams for notifications
export teamsHook=https://outlook.office.com/webhook/blabla

helm upgrade -i flagger flagger/flagger \
--reuse-values \
--set msteams.url=$teamsHook

# You can use Prometheus GUI to check on metrics
kubectl port-forward svc/flagger-prometheus 12345:9090
```

### Canary

Deploy app and make sure Flagger has initiated.

```bash
cd /flagger/ingress-app-canary
helm upgrade -i ingress-app-canary . \
    --set imagetag="1" \
    --set ingressip=$(kubectl get svc nginx-ingress-controller -o jsonpath={.status.loadBalancer.ingress[0].ip})

kubectl describe canary myweb
```

Upgrade application to new version and observ Flagger rolling out release.

```bash
# Upgrade app to version 2
helm upgrade -i ingress-app-canary . \
    --set imagetag="2" \
    --reuse-values

# Check canary object
kubectl describe canary myweb

# Continuously test what gets returned
while true; do curl 51.105.168.86.xip.io; echo; done

# Check Flagger logs
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=flagger -o jsonpath="{.items[0].metadata.name}") -f | jq .msg
```

Clean up

```bash
helm delete ingress-app-canary
```

### A/B testing
Deploy app and make sure Flagger has initiated.

```bash
cd /flagger/ingress-app-ab
helm upgrade -i ingress-app-ab . \
    --set imagetag="1" \
    --set ingressip=$(kubectl get svc nginx-ingress-controller -o jsonpath={.status.loadBalancer.ingress[0].ip})

kubectl describe canary myweb
```


Upgrade application to new version and observe Flagger using A/B testing.

```bash
helm upgrade -i ingress-app-ab . \
    --set imagetag="2" \
    --reuse-values

kubectl describe canary myweb

# Check Flagger logs
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=flagger -o jsonpath="{.items[0].metadata.name}") -f | jq .msg
```

Standard requests are going to v1.

```bash
curl 51.105.168.86.xip.io
```

We can use header or cookie to get to v2.

```bash
curl -H 'tester: true' 51.105.168.86.xip.io
curl -b 'tester=always' 51.105.168.86.xip.io
```

Clean up.

```bash
helm delete ingress-app-ab
helm delete flagger
kubectl delete crd canaries.flagger.app
```

## Flagger with Istio
NGINX Ingress implementation is great and easy to use, but limited to test changes in services exposed outside of your cluster such as frontend or APIs accessed from client etc. Should you need to use canary or A/B testing for communication between two internal services within Kubernetes cluster, Service Mesh can be used to achieve this.

### Install Istio
First download istioctl.

```
cd ./istio
wget https://github.com/istio/istio/releases/download/1.4.2/istioctl-1.4.2-linux.tar.gz
tar -xvf istioctl-1.4.2-linux.tar.gz
sudo mv ./istioctl /usr/local/bin/
rm -rf istioctl-1.4.2-linux.tar.gz
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

### Install Flagger
Install Flagger

```bash
# Add Flagger repo
helm repo add flagger https://flagger.app

# Install Flagger
helm upgrade -i flagger flagger/flagger \
    --set metricsServer=http://prometheus.istio-system:9090 \
    --set meshProvider=istio

# Optionaly add webhook to Microsoft Teams for notifications
export teamsHook=https://outlook.office.com/webhook/blabla

helm upgrade -i flagger flagger/flagger \
--reuse-values \
--set msteams.url=$teamsHook

# You can use Prometheus GUI to check on metrics
kubectl port-forward svc/prometheus -n istio-system 12345:9090
```

### Canary release

Deploy services.

```bash
cd flagger/istio-canary/
kubectl label namespace default istio-injection=enabled
helm upgrade -i istio-app-canary . \
    --set imagetag="1"
```

Test internal communication.

```bash
kubectl exec -ti \
    $(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}") \
    -- curl myweb

kubectl describe canary myweb
```

Upgrade application to new version and observe Flagger advancing rollout.

```bash
# Upgrade app to version 2
helm upgrade -i istio-app-canary . \
    --set imagetag="2" \
    --reuse-values

# Check canary object
kubectl describe canary myweb

# Continuous testing of communication from one service to another
kubectl exec -ti \
    $(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}") \
    -- bash -c 'while true; do curl myweb; sleep 0.2; echo; done'

# Check Flagger logs
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=flagger -o jsonpath="{.items[0].metadata.name}") -f | jq .msg
```

Simulate "failing upgrade" by using non-existing image tag. Flagger will not advance rollout if success rate (200 response code) is less than 99% of requests to canary (as per our configuration) and will rollback after timeout.

```bash
# Upgrade to error version that returns 503
helm upgrade -i istio-app-canary . \
    --set imagetag="error" \
    --reuse-values

# Check canary object
kubectl describe canary myweb

# Continuous testing of communication from one service to another
kubectl exec -ti \
    $(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}") \
    -- bash -c 'while true; do curl myweb; sleep 0.2; echo; done'

# Check Flagger logs
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=flagger -o jsonpath="{.items[0].metadata.name}") -f | jq .msg
```

Clean up

```bash
helm delete istio-app-canary
```

### A/B testing

Deploy services.

```bash
cd flagger/istio-ab/
kubectl label namespace default istio-injection=enabled
helm upgrade -i istio-app-ab . \
    --set imagetag="1"
```

Test internal communication.

```bash
kubectl exec -ti \
    $(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}") \
    -- curl myweb

kubectl describe canary myweb
```

Upgrade application to new version and observe Flagger advancing A/B testing.

```bash
# Upgrade app to version 2
helm upgrade -i istio-app-ab . \
    --set imagetag="2" \
    --reuse-values

# Check canary object
kubectl describe canary myweb

# Test accessing new version
kubectl exec -ti \
    $(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}") \
    -- curl -H 'tester: true' myweb

# Check Flagger logs
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=flagger -o jsonpath="{.items[0].metadata.name}") -f | jq .msg
```

Clean up

```bash
helm delete istio-app-ab
```

### Clean uo
```bash
cd ./istio
istioctl manifest generate -f istioConfig.yaml | kubectl delete -n istio-system -f -
kubectl get secret --all-namespaces -o json | jq '.items[].metadata | ["kubectl delete secret -n", .namespace, .name] | join(" ")' -r | fgrep "istio." | xargs -t0 bash -c
helm delete flagger
```
