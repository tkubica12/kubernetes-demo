# Service Mesh
Service Mesh technologies can bring intelligent network behavior to platform so application developers can leverage that without building specific support in their code. Most typical areas covered are:
- Traffic split - ability to decide where to route traffic based on percentage, headers or other conditions to enable canary releases or A/B testing
- Traffic control - implementing patterns like retry, circuit breaker, rate limit or mutual TLS authentication and encryption
- Visibility - ability to capture traffic statics and logging

# Scenarios
- [Istio](istio.md)
- [Linkerd](linkerd.md)

TBD:
- Service Mesh Interface
- Consul Connect

# Why Service Mesh?
First let's deploy simple services and investigate limitations of plain Kubernetes.

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