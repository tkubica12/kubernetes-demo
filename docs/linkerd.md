- [Install Linkerd CLI](#install-linkerd-cli)
- [Install Linkerd](#install-linkerd)
- [Accessing Linkerd dashboard](#accessing-linkerd-dashboard)
- [Install &quot;app&quot; and make sure Linkerd sidecar is injected](#install-quotappquot-and-make-sure-linkerd-sidecar-is-injected)
  - [Retry functionality](#retry-functionality)
  - [Canary deployments (traffic split)](#canary-deployments-traffic-split)
- [Load balancing](#load-balancing)
- [mTLS between services and using Linkerd tap for troubleshooting](#mtls-between-services-and-using-linkerd-tap-for-troubleshooting)

# Install Linkerd CLI
```bash
export LINKERD_VERSION=stable-2.6.0
curl -sLO "https://github.com/linkerd/linkerd2/releases/download/$LINKERD_VERSION/linkerd2-cli-$LINKERD_VERSION-linux"
sudo -E mv linkerd2-cli-$LINKERD_VERSION-linux /usr/bin/linkerd
```

# Install Linkerd

```bash
linkerd check --pre
linkerd install | kubectl apply -f -
```

# Accessing Linkerd dashboard

```bash
linkerd dashboard
```

# Install "app" and make sure Linkerd sidecar is injected
```bash
kubectl apply -f client.yaml
kubectl apply -f retryBackend.yaml
kubectl apply -f canary.yaml
```

## Retry functionality
First run client without any service profile defined. We are using retry backend application that acceps failRate as argument and based on this percentage will either respond or crash the Pod. We will use 50% chance of getting no response and container crash.

```bash
export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")
kubectl exec $clientPod -c client -- curl -vs -m 30 retry-service?failRate=50
```

Now we will create service profile with retry enabled.

```bash
kubectl apply -f retryProfile.yaml
kubectl exec $clientPod -c client -- curl -vs -m 30 retry-service?failRate=50
```

As you can see you now get response even if your first request causes container to crash. This demonstrates retry functionality in Linkerd.

## Canary deployments (traffic split)
Linkerd allows you to have better control over routing your traffic to different versions of services independently of infrastructure configuration (eg. number of pods with each service).

In our example we have 3 instances of v1 and 3 instances of v2 so we are 50% likely to hit v2.

```bash
kubectl exec $clientPod -c client -- bash -c 'while true; do curl -s myweb-service; echo; done'
```

Let's now configure Linkerd to send just 10% of traffic to v2. Linkerd use Service objects to identify versions of our service, so we will create myweb-service-v1 and myweb-service-v2. To configure Traffic Split Linkerd uses Service Mesh Interface API with object TrafficSplit. Deploy and check we are now 90% likely to hit v1.

```bash
kubectl apply -f canary10percent.yaml
kubectl exec $clientPod -c client -- bash -c 'while true; do curl -s myweb-service; echo; done'
```

What about serving v2 only for user with specific cookie? Linkerd and SMI currently does not support header or cookie based routing between services in mesh. But if user traffic is concerned this can be done on Ingress implementation and automated for example with Flagger or Azure DevOps.

# Load balancing
Linkerd uses exponentially weighted moving average algorithm to load-balance traffic and support scenarios with HTTP/2 and gRPC where standard balancing in Kubernetes is not very effective.

#  mTLS between services and using Linkerd tap for troubleshooting
Linkerd enables creation of tap to listen for packets for troubleshooting. All communications between services are TLS encrypted (mTLS) that are part of Service Mesh. note that communications outside of service mesh szstem are note encrypted.

Run linkerd tap and watch traffic
```bash
export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")

# Structured with full details
linkerd tap pod/$clientPod -o json

# Basic details
linkerd tap pod/$clientPod

# See only traffic that was not encrypted my service mesh
linkerd tap pod/$clientPod | grep -v tls=true
```

You will see a lot of traffic and can generate more traffic between services.

```bash
export clientPod=$(kubectl get pods -l app=client -o jsonpath="{.items[0].metadata.name}")
kubectl exec $clientPod -c client -- curl -s myweb-service
kubectl exec $clientPod -c client -- curl www.tomaskubica.cz
```