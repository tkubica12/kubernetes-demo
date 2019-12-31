- [Network policy](#network-policy)
  - [Create web and db pod](#create-web-and-db-pod)
  - [Make sure web can both ping and mysql to db pod](#make-sure-web-can-both-ping-and-mysql-to-db-pod)
  - [Create network policy to allow mysql communication only](#create-network-policy-to-allow-mysql-communication-only)

# Network policy

Default Kubernetes does not implement Network Policy. When provisioning AKS you can select Network Policy using Azure plugin (implemented on fabric level similar to how NSG works) or Calico. In this demo we will create Web and DB and provide strict policy what and how can communicate. Make sure your cluster was built with Network Policy enabled.

## Create web and db pod
```
kubectl create -f podNetWeb.yaml
kubectl create -f podNetDB.yaml
kubectl exec net-web ip a
kubectl exec net-db ip a
```

## Make sure web can both ping and mysql to db pod
```
export dbip=$(kubectl get pod net-db -o json | jq -r '.status.podIP')
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```

## Create network policy to allow mysql communication only
```
kubectl create -f networkPolicy.yaml
kubectl exec -ti net-web -- mysql -h $dbip -uroot -pAzure12345678
kubectl exec -ti net-web -- ping -c 3 $dbip
```