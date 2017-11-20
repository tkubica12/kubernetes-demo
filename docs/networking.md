# Networking
We have seen a lot of networking already: internal ballancing and service discovery, external balancing with automatic integration to Azure Load Balancer with public IP, communication between pods in container etc. In this section we will focus on some other aspects namely networking policy.

- [Networking](#networking)
    - [Azure CNI](#azure-cni)
    - [Network policy with Calico](#network-policy-with-calico)
        - [I will reference my kubectl config pointing to Calico-enabled cluster](#i-will-reference-my-kubectl-config-pointing-to-calico-enabled-cluster)
        - [Create web and db pod](#create-web-and-db-pod)
        - [Make sure web can both ping and mysql to db pod](#make-sure-web-can-both-ping-and-mysql-to-db-pod)
        - [Create network policy to allow mysql communication only](#create-network-policy-to-allow-mysql-communication-only)

## Azure CNI
In Azure CNI cluster demonstrate how containers take IP addresses directly from VNET. Access pod directly from VM deployed in the same VNET.

## Network policy with Calico
Calico is plugin that implements Kubernetes network policy, namely microsegmentation (L4 filtering between pods). In this demo we will create Web and DB and provide strict policy what and how can communicate.

### I will reference my kubectl config pointing to Calico-enabled cluster
```
kubectx mykubecalico
```

### Create web and db pod
```
kubectl create -f podNetWeb.yaml
kubectl create -f podNetDB.yaml
kubectl exec net-web ip a
kubectl exec net-db ip a
```

### Make sure web can both ping and mysql to db pod
```
export dbip=$(kubectl get pod net-db -o json | jq -r '.status.podIP')
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```

### Create network policy to allow mysql communication only
```
kubectl create -f networkPolicy.yaml
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```