# Monitoring

- [Monitoring](#monitoring)
    - [Prepare Log Analytics / OMS](#prepare-log-analytics-oms)
    - [Deploy agent](#deploy-agent)
    - [Generate message in app](#generate-message-in-app)
    - [Log Analytics](#log-analytics)
    - [Clean up](#clean-up)
    
## Prepare Log Analytics / OMS
Create Log Analytics account and gather workspace ID and key.
Create Container Monitoring Solution.

## Deploy agent
Modify daemonSetOMS.yaml with your workspace ID and key.

```
kubectl create -f daemonSetOMS.yaml
```

## Generate message in app
```
kubectl create -f podUbuntu.yaml
kubectl exec -ti ubuntu -- logger My app has just logged something

```
## Log Analytics
Container performance example
```
Perf
 | where ObjectName == "Container" and CounterName == "Disk Reads MB"
 | summarize sum(CounterValue) by InstanceName, bin(TimeGenerated, 5m)
 | render timechart 
```

## Clean up
```
kubectl delete -f podUbuntu.yaml
kubectl delete -f daemonSetOMS.yaml
```
