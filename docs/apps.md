# Deploying apps with Pods, Deployments and Services
This set of demos focus on stateless applications like APIs or web frontend. We will deploy application, balance it internally and externally, do rolling upgrade, deploy both Linux and Windows containers and make sure they can access each other.

- [Deploying apps with Pods, Deployments and Services](#deploying-apps-with-pods-deployments-and-services)
  - [Deploy multiple pods with Deployment](#deploy-multiple-pods-with-deployment)
  - [Create service to balance traffic internally](#create-service-to-balance-traffic-internally)
  - [Create externally accessible service with Azure LB with Public IP](#create-externally-accessible-service-with-azure-lb-with-public-ip)
  - [Create externally accessible service with Azure LB with Private IP](#create-externally-accessible-service-with-azure-lb-with-private-ip)
  - [Predictable (static) external IP addresses](#predictable-static-external-ip-addresses)
  - [Using Service without balancing (headless service)](#using-service-without-balancing-headless-service)
  - [Using Service for balancing apps deployed outside Kubernetes cluster](#using-service-for-balancing-apps-deployed-outside-kubernetes-cluster)
  - [Session persistence](#session-persistence)
  - [Preserving client source IP](#preserving-client-source-ip)
    - [Why Kubernetes do SNAT by default](#why-kubernetes-do-snat-by-default)
    - [How can you preserve client IP and what are negative implications](#how-can-you-preserve-client-ip-and-what-are-negative-implications)
    - [Recomendation of using this with Ingress only and then use X-Forwarded-For](#recomendation-of-using-this-with-ingress-only-and-then-use-x-forwarded-for)
  - [Rolling upgrade](#rolling-upgrade)
  - [Canary releases with multiple deployments under single Service](#canary-releases-with-multiple-deployments-under-single-service)
  - [Using liveness and readiness probes to monitor Pod status](#using-liveness-and-readiness-probes-to-monitor-pod-status)
    - [Reacting on dead instances with liveness probe](#reacting-on-dead-instances-with-liveness-probe)
    - [Signal overloaded instance with readiness probe](#signal-overloaded-instance-with-readiness-probe)
  - [Pod inicialization with init containers](#pod-inicialization-with-init-containers)
  - [Reacting to SIGTERM in your application](#reacting-to-sigterm-in-your-application)
  - [Running processes close to each other](#running-processes-close-to-each-other)
    - [Multiple processes in single container](#multiple-processes-in-single-container)
    - [Multiple containers in single Pod](#multiple-containers-in-single-pod)
    - [Pods affinity](#pods-affinity)
  - [Deploy IIS on Windows pool](#deploy-iis-on-windows-pool)
  - [Test Linux to Windows communication (currently only for ACS mixed cluster, no AKS)](#test-linux-to-windows-communication-currently-only-for-acs-mixed-cluster-no-aks)
  - [Clean up](#clean-up)

## Deploy multiple pods with Deployment
We are going to deploy simple web application with 3 instances.

```bash
kubectl apply -f deploymentWeb1.yaml
kubectl get deployments -w
kubectl get pods -o wide
```

We will now kill our Pod and see how Kubernetes will make sure our environment is consistent with desired state (which means create Pod again).

```bash
kubectl delete pod myweb-deployment-7cd8bbd97c-9c26b    # replace with your Pod name
kubectl get pods
```

Now let's play a little bit with labels. There are few ways how you can print it on output or filter by label. Try it out.

```bash
# print all labels
kubectl get pods --show-labels    

# filter by label
kubectl get pods -l app=todo

# add label column
kubectl get pods -L app
```

Note that the way how ReplicaSet (created by Deployment) is checking whether environment comply with desired state is by looking at labels. Look for Selector in output.

```bash
kubectl get rs
kubectl describe rs myweb-deployment-7cd8bbd97c   # put your actual rs name here
```

Suppose now that one of your Pods behaves strangely. You want to get it out, but not kill it, so you can do some more troubleshooting. We can edit Pod and change its label app: myweb to something else such as app: mywebisolated. What you expect to happen?

```bash
kubectl edit pod myweb-deployment-7cd8bbd97c-gnkq2    # change to your Pod name
kubectl get pods --show-labels
```

What happened? As we have changed label ReplicaSet controller no longer see 3 instances with desired labels, just 2. Therefore it created one additional instance. What will happen if you change label back to its original value?

```bash
kubectl edit pod myweb-deployment-7cd8bbd97c-gnkq2    # change to your Pod name
kubectl get pods --show-labels
```

Kubernetes have killed one of your Pods. Now we have 4 instances, but desired state is 3, so controller removed one of those.

## Create service to balance traffic internally
Create internal service and make sure it is accessible from within Kubernetes cluster. Try multiple times to se responses from different nodes in balancing pool.

```
kubectl apply -f podUbuntu.yaml
kubectl apply -f serviceWeb.yaml
kubectl get services
kubectl exec ubuntu -- curl -s myweb-service
```

## Create externally accessible service with Azure LB with Public IP
In this example we make service accessible for users via Azure Load Balancer leveraging public IP address.

```
kubectl apply -f serviceWebExtPublic.yaml

export extPublicIP=$(kubectl get service myweb-service-ext-public -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl $extPublicIP
```

## Create externally accessible service with Azure LB with Private IP
In this example we make service accessible for internal users via Azure Load Balancer with private IP address so service only from VNET (or peered networks or on-premises network connected via S2S VPN or ExpressRoute).

```
kubectl apply -f serviceWebExtPrivate.yaml
```

To test we will connect to VM that runs in the same VNET.
```
export vmIp=$(az network public-ip show -n mytestingvmPublicIP -g akstestingvm --query ipAddress -o tsv)
export extPrivateIP=$(kubectl get service myweb-service-ext-private -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ssh tomas@$vmIp curl $extPrivateIP
```

## Predictable (static) external IP addresses
Kubernetes Service together with Azure will assign external IP for you - either free Private IP or create new Public IP. Sometimes you might need this to be more predictable. For example you can create Public IP in your resource group in advance and setup additional systems (DNS records, whitelisting). You specify existing public or private IP in Service definition statically.

```
kubectl apply -f serviceWebExtPrivateStatic.yaml
```

## Using Service without balancing (headless service)
In most cases it is best to access your balanced apps via Service providing virtual IP and balancing. Rarely your client is more clever and can implement some more advanced algorithm (metric-based balancing, sharding, ...) so you want your client to get all healthy Pod IP addresses. In other word you want to leverage service discovery capabilities of Service without using virtual IP. Let's try it. Deploy headless Service.

```
kubectl apply -f serviceWebHeadless.yaml
```

We will now try DNS request to regular service (with virtual ClusterIP) versus headless service. First returns Cluster IP A record while second returns multiple A record (one for each healthy Pod).
```
kubectl exec ubuntu -- dig myweb-service.default.svc.cluster.local
kubectl exec ubuntu -- dig myweb-service-headless.default.svc.cluster.local
```

## Using Service for balancing apps deployed outside Kubernetes cluster
Suppose you have one of your services running outside of Kubernetes cluster in Azure VM, but you plan to migrate it to your cluster soon. You can create Service object, but rather than using selector to match pods (which build list of endpoint IPs - let say balancing pool) you can specify endpoints manually. This way other services can use this Service using internal mechanisms and you can later migrate that component to Kubernetes and replace fixed endpoints with selector. Note that you can even specify multiple endpoints and Service will do balancing (but it will not be able to check health status because it is not running in cluster therefore if you need HA you better use something like Azure LB externally).

Create service and point to our external VM. We run SSH server there. We do not have client installed in our ubuntu Pod, but we can do curl to port 22 (it will fail with protocol mismatch message, but we will see identificator from other side).

```
kubectl apply -f serviceOut.yaml
kubectl exec -it ubuntu -- curl out-service:22
```

## Session persistence
By default service does round robin so your client can connect to different instance every request. This should not be problem with truly stateless scenarios and does allow you for very good balancing. But in some cases even stateless applications might benefit from session persistence:
* You are using canary deployment so some instances might run newer version of your app then others and such inconsistencies might be unwanted for user experience
* You are terminating TLS right in instances and moving to another means renegotiating and therefore increase latency
* Your API use paging where client request data page by page and you are prefetching data from database in advance. Connecting to different instance can have performance penalty (data not prefetched)

```
kubectl apply -f serviceWebSession.yaml
```

Using podUbuntu from previous demos check out results. You should see different instances when talking to myweb-service, but not when talking to myweb-server-session.

```
kubectl exec ubuntu -- /bin/bash -c 'for i in {1..10}; do curl -s myweb-service; done'
kubectl exec ubuntu -- /bin/bash -c 'for i in {1..10}; do curl -s myweb-service-session; done'
```

Please note that while servicing 100s of client enabling session persistence might not have dramatic effect on fair load over existing instances, when you have just one client side (client IP) session affinity in effect turn any balancing off!

## Preserving client source IP
By default Kubernetes Service is doing SNAT before sending traffic to Pod so client IP information is lost. This might not be problem unless you want to:
* Whitelisting access to service based on source IP addresses
* Log client IP address (legal requirement, location tracking, ...)

### Why Kubernetes do SNAT by default
When you deploy service of type LoadBalancer underlying IaaS will deploy load balancer, Azure LB in our case. This balancer is configured to send traffic to any node of your cluster. If traffic arrives on node that does not hoste any instance (Pod) of that Service, it will proxy traffic to different node. Current Kubernetes implementation need to do SNAT for this to work.

### How can you preserve client IP and what are negative implications
In Azure you can use externalTrafficPolicy (part of spec section of Service definition) set to Local. This ensures that Azure LB does balance traffic only to nodes where Pod replica runs and Service on node is sending traffic only to Pods available locally. With that there is no need to reroute traffic to different node, no added latency and  there is no SNAT required. This settings preserves actual client IP in packet entering Pod.

Using this might create suboptimal load distribution if number of replicas is close to number of nodes or more. Under such conditions some nodes might get more than one replica (Pod) running. Since there is no rerouting now traffic distribution is not done on Pods level but rather Nodes level. Example:

node1 -> pod1, pod4
node2 -> pod2
node3 -> pod3

With default configuration each pod will get 25% of new connections. With externalTrafficPolicy set to Local, each node will get 33% of new connections. Therefor pod1 and pod4 will get just 16,5% connections each while pod2 and pod3 will get 33% each.

Let's create Deployment and Service configured for Local. This app will return Client IP and we expect this to be real IP of the client.

```
kubectl apply -f preserveClientIp.yaml
export extPreserveIp=$(kubectl get service httpecho -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl $extPreserveIp
```

### Recomendation of using this with Ingress only and then use X-Forwarded-For
Good solution if you need client IP information is to use it for [Ingress](docs/networking.md), but not for other Services. By deploying ingress controller in Service with externalTrafficPolicy Local, your nginx proxy will see client IP. This means you can do whitelisting (source IP filters) in you Ingress definition. Traffic distribution problem is virtualy non existent because you typically run ingress on one or few nodes in cluster, but rarely you want more replicas then number of nodes.

## Rolling upgrade
We will now do rolling upgrade of our application to new version. We are going to change deployment to use different container with v2 of our app.
```
kubectl apply -f deploymentWeb2.yaml
```

Watch pods being rolled (Deployment is using ReplicaSets so how it works is that it creates new ReplicaSet for new version and scales it up while scaling previous down accordinlgy until previous one is scaled to 0).
```
kubectl get pods -w
```

What if something went wrong and you want to rollback? In this demo we have used pure declarative model, so we have previous version of our Deployment yaml available, so we can easily run this:
```
kubectl apply -f deploymentWeb1.yaml
```

In case you have used imperative model or for some reason getting previous YAML is a bit difficult (eg. you do Continuous Deployment and you are reverting something that your robot deployed, therefore it might take you relatively long time to find right file) Kubernetes Deployment actually stores previous state so you can rollback using this:
```
kubectl rollout undo deployment/myweb-deployment
```

## Canary releases with multiple deployments under single Service
You might want to have tighter control about rolling upgrade. For examle you want canary release like serving small percentage of clients new version for long enough time to gather feedback (hours). Or you want to control ratio between old and new version over time (for example roll 20% of requests every hour).

We are going to deploy two separate deployments - one with v1 and one with v2 of our web app. As they share common label we are using in selector for service, Pods of both deployments will be in balancing pool. As we have 3 replicas of v1 and 1 replica of v2, we are much more likely to hit v1.

```
kubectl apply -f canary.yaml
kubectl exec ubuntu -- /bin/bash -c 'for i in {1..10}; do curl -s canaryweb; done'
```

We can independently scale v1 and v2 as we want to have more and more v2s available. Let's rescale our deployments and check we are now much more likely to hit v2.

```
kubectl scale deployment canaryweb-v1 --replicas 1
kubectl scale deployment canaryweb-v2 --replicas 3
kubectl exec ubuntu -- /bin/bash -c 'for i in {1..10}; do curl -s canaryweb; done'
```

Even we have more control over process compared to Deployment roling upgrade there are still few limitations:
* Percentage for each version is done by scaling actual resources. It is then hard to send just 1% of traffic to v2 because that would mean you need to have 99 Pods of v1
* Since Service does not support cookie based session persistence, when more clients access service from behind NAT (such as from their corporate network) you cannot guarantee they hit the same version every time
* You might require selecting who gets v2 by matching some header in request (eg. testers or beta customers)

If you need even more control you can either:
* Deploy Istio for Service Mesh [see here](docs/istio.md)
* Create two separate services and solve this using reverse proxy such as NGINX, Envoy or Traefik

## Using liveness and readiness probes to monitor Pod status
Kubernetes will by default react on your main process crash and will restart it. Sometimes you might experience rather hang so app is not responding, but process is up. We will add liveness probe to detect this and restart. Also your instance might not be ready to serve requests. Maybe it is booting or it is overloaded and you do not want it to receive additional traffic for some time. We will signal this with readiness probe.

In order to simulate this we will use simple Python app that you can find probesDemoApp. I have already created container with it and pushed it to Docker Hub. App is responding with 5 seconds delay, but with 15 seconds delay when simulating instance overloaded scenario. There are following APIs available:
* /kill will terminate process
* /hang will keep process running, but stop responding
* /health checks health of app (used for liveness probe)
* /setReady will flag instance as ready (default)
* /setNotReady will simulate overloaded scenario by prolonging response to 15 seconds
* /readiness will return 200 under normal conditions, but 503 when flagged as overloaded (with /setNotReady)

### Reacting on dead instances with liveness probe
Let's create deployment and service without liveness probe and test it out.

```
kubectl apply -f deploymentNoLiveness.yaml
```

Get external service public IP address and test it.

```
export lfPublicIP=$(kubectl get service lf -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl $lfPublicIP
```

Simulate application crash. Kubernetes will automatically restart.

```
curl $lfPublicIP/kill
kubectl get pods
```

Simulate application hang. Kubernetes will not react and our app is down.

```
curl $lfPublicIP/hang
curl $lfPublicIP
```

We will now solve this by implementing health probe.

```
kubectl delete deployment lf
kubectl apply -f deploymentLiveness.yaml
```

Make app hang. After few seconds Kubernetes will detect this and restart.

```
curl $lfPublicIP/hang
kubectl get pods -w
curl $lfPublicIP
```

### Signal overloaded instance with readiness probe
Let's continue our example by testing behavior with simulation of overloaded instance. First let's increase replicas to 2.

```
kubectl scale deployment lf --replicas 2
```

Run load test (for example with VSTS). Response time should always be around 5 seconds.

Now let's flag one of instances as overloaded so its response time increase to 15 seconds.

```
kubectl describe service lf | grep Endpoints
curl $lfPublicIP/setNotReady
kubectl describe service lf | grep Endpoints
```

If we run test now we will see significanlty longer average latency, because some requests are handle by not overloaded instance (5 seconds delay) and some by overloaded one (15 seconds delay).

We will now want our Service to stop sending requests to instance that is overloaded. Instance will signal this via returning 503 on readiness probe.

```
kubectl delete deployment lf
kubectl apply -f deploymentLivenessReadiness.yaml
```

Rerun your load test. Initialy both instances are serving requests. In the middle of the test flag one of instances as overloaded. Due to readiness probe Kubernetes will remove it from balancing pool so it will not receive any new traffic. Note that Kubernetes will not hurt this instance (as health is still OK), so it can continue working on existing tasks and later can itself join back the pool by starting to return 200 again on readiness probe.

```
kubectl describe service lf | grep Endpoints
curl $lfPublicIP/setNotReady
kubectl describe service lf | grep Endpoints
```

## Pod inicialization with init containers
If you define more containers in your Pod they all start together. Sometimes you might want to do some initialization before your app containers are started. Maybe you want to download something first, store on volume and when this is ready start your application. Maybe you want to prefill Redis cache before main container starts. Or you might to wait until some external systems are ready before you start main container. Way to achieve this is to use init containers. Those do start sequentialy. When first init container starts Kubernetes wait for its process to end. Then next and next (if configured). When all init containers exited, main containers are started.

In our example we will use init container to download HTML page from external source (and wait 5 seconds just for demo purposes). Page will be stored in volume and mapped to our main container (NGINX) that will then start and serve this content.

```
kubectl apply -f initDemo.yaml
kubectl get pods -w
```

We will see how container first goes to PodInitializing phase and then Running. You can check NGINX is serving our page using port-forward to Pod.

```
kubectl port-forward pod/initdemo :80
```

## Reacting to SIGTERM in your application
When Kubernetes need to take down your Pod due to scale down or draining Node because of pending reboot, your containers will get SIGTERM signal and by default 30 seconds period to gracefully shut down. This period is configurable in Pod definition. You can register to those OS events and do whatever is needed to maintain consistency. You might want to signal 503 on readiness probe, finish current requests and tasks, flush data to persistent storage or inform other members of application cluster about your leave (for example handover master role to different instance).

We will use simple Python app in folder sigtermDemoApp to register for sigterm. For demo purposes we will be printing Running to stdout and when we receive sigterm we will start to print Cleaning up. I have already packaged this up to Docker container and published on Docker Hub.

Start Pod in interactive mode so we see live output.

```
kubectl run -it sigterm --image tkubica/sigterm:handled --restart Never
```

In second window kill this Pod.

```
kubectl delete pod sigterm
```

You should see application reacting on sigterm.

## Running processes close to each other
Sometimes you have processes that talk to each other a lot and introducing additional network hops has negative effect on latency and performance of your application. There are couple of ways to solve this and each comes with advantages and disadvantages.

### Multiple processes in single container
It is OK for your process to start additional processes or threads. What if you need run two independent processes for example for troubleshooting purposes? I am not big fan of this approach, but you can create container that will start your main process as well as other one - debugging tool, SSH daemon etc. Better way to implement such "helpers" is not to put them in the same container, but rather leverage side-car pattern and deploy multiple containers in single. Nevertheless if you realy need start more than one process in container it is good to use some lightweight process manager. If you just start with bash script that would put some processes to background Kubernetes is loosing control and cannot maitain health status (Kubernetes restarts if your PID 1 crashes - but in such that is bash, if process in background goes down, bash is still up and Kubernetes will not restart your container). Using something like systemd would be too heavy.

In such cases you can use supervisord - lightweight process manager. Checkout example in folder multiProcessContainer. I have build this image and pushed to Docker Hub. You can start it 

```
kubectl apply -f podMultiProcess.yaml
```

Supervisord becomes PID 1 and maintains two processes running - tail and sleep. We can kill either one to simulate crash and supervisord will restart it. If suprevisord itself would fail Kubernetes will restart whole container.

```
kubectl exec -it supervisord -- bash
root@supervisord:/# ps aux
USER        PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root          1  0.2  0.4  47788 18304 ?        Ss   08:51   0:00 /usr/bin/python /usr/bin/supervisord
root          7  0.0  0.0   4416   788 ?        S    08:51   0:00 tail -f /dev/null
root          8  0.0  0.0   4384   684 ?        S    08:51   0:00 sleep infinity
root          9  0.0  0.0  18276  3244 ?        Ss   08:52   0:00 bash
root         18  0.0  0.0  34432  2876 ?        R+   08:52   0:00 ps aux
root@supervisord:/# kill 7
root@supervisord:/# ps aux
USER        PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root          1  0.1  0.4  47992 18392 ?        Ss   08:51   0:00 /usr/bin/python /usr/bin/supervisord
root          8  0.0  0.0   4384   684 ?        S    08:51   0:00 sleep infinity
root          9  0.0  0.0  18276  3244 ?        Ss   08:52   0:00 bash
root         19  0.0  0.0   4416   708 ?        S    08:52   0:00 tail -f /dev/null
root         20  0.0  0.0  34432  2820 ?        R+   08:52   0:00 ps aux
root@supervisord:/# kill 8
root@supervisord:/# ps aux
USER        PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root          1  0.1  0.4  47992 18392 ?        Ss   08:51   0:00 /usr/bin/python /usr/bin/supervisord
root          9  0.0  0.0  18276  3316 ?        Ss   08:52   0:00 bash
root         19  0.0  0.0   4416   708 ?        S    08:52   0:00 tail -f /dev/null
root         21  0.0  0.0   4384   664 ?        S    08:52   0:00 sleep infinity
root         22  0.0  0.0  34432  2820 ?        R+   08:52   0:00 ps aux
```

### Multiple containers in single Pod
Running multiple processes in the same container creates too tight binding. Kubernetes comes with concept of Pod that can actually hold more that one container and they can communicate with each other. You can use network communication via loopback 127.0.0.1, see the same files in Volume or write to /dev/shm to share memory.

Typical use is with side-car pattern such as:
* Adapter - change the way how things are exposed to outside world. For example if your app writes its metrics to file and you want to expose that information via API, you can store that file in shared Volume and have second container convert that information into API service. 
* Ambassador - second container can provide services for communication going out of your app container. Rather than connecting to external service directly you app will talk to 127.0.0.1 where second container will pick it app and proxy communication outside. With that you can implement things like sharding, retry, circuit breaker or TLS encryption. Service Mesh systems like [Istio](docs/istio.md) leverage this
* Helpers - for example second container can be downloading static content for your web server or provide dynamic configurations for your app

In our first example we will use shared Volume and second container to download HTML content that primary NGINX container is serving.
```
kubectl apply -f podMultiContainerVolume.yaml
kubectl port-forward pod/sidecar :80
```

In our second example we will test pods can listen to each other via loopback. Our primary container will use 127.0.0.1 to talk to second container with nginx.
```
kubectl apply -f podMultiContainerNet.yaml
kubectl exec -c app sidecar2 -- curl 127.0.0.1
```

This technique is very good, but might not be the best one to bound two separate services that just happen to talk to each other a lot. In such case you cannot scale them independently. If you need as an example stateless service that talks to Redis deployment within cluster this is issue. It is good to have containers close to each other so cache reads are very fast, but when you need to scale your app service to 20 instances Redis will scale also. Overhead of that much replicas will be very high.

### Pods affinity
When you have two separated services that often talk to each other, but still want to maintain independent scaling, you might want to have separate Pods or Deployments, but make schedule place those Pod on the same Node so there no network hops added (note that if you use Service on top of Deployment it will by default balance traffic even over network hops - see Service section to see how to change this configuration so local-only will be used). There is concept of Pod affinity we will explore now.

Let's start by deploying first Pod (it can be Deployment, but let's keep this simple for now).
```
kubectl apply -f podAffinity1.yaml
```

We now want to deploy second Pod or Deployment, but tell Kubernetes to schedule it only to Nodes that our first Pod (or Pods of Deployment). There two ways to define this. In our demo we will use requiredDuringSchedulingIgnoredDuringExecution which means Kubernetes will schedule second Pod only to Node that runs first one. If that is not possible (not enough capacity), deployment will fail. You might also want to "preffer" placing it on the same Node, but if that is not possible, it is better to place it elsewhere than doing nothing. This can be implemented using prefferedDuringSchedulingIgnoredDuringExecution.

Deploy second pod and check it is on the same Node.
```
kubectl apply -f podAffinity2.yaml
kubectl get pods -o wide
```

## Deploy IIS on Windows pool
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
kubectl delete deployments --all
kubectl delete pods --all
kubectl delete services --all
```
