# RBAC with AAD and ACR

**This section has not yet been updated for AKS**

When using Kubernetes in enterprise there might be need to role based access control and strong authentication. In this demo we will see how to to use namespaces in Kubernetes to isolate resources from control plane level, how to authenticate user with strong Azure Active Directory authentication and how to authorize what each user can do with Kubernetes RBAC. Also we will look into private registry, how to secure it and make sure company provided images are used.

- [RBAC with AAD and ACR](#rbac-with-aad-and-acr)
    - [Switch to our mixed ACS cluster](#switch-to-our-mixed-acs-cluster)
    - [Create namespace with some Pod](#create-namespace-with-some-pod)
    - [Create RBAC credentials and RoleBinding](#create-rbac-credentials-and-rolebinding)
    - [Create configuration context and switch to it](#create-configuration-context-and-switch-to-it)
    - [Test RBAC](#test-rbac)
        - [Make sure user can read Pods](#make-sure-user-can-read-pods)
        - [Make sure user can create Pod](#make-sure-user-can-create-pod)
        - [Check, that user cannot create other objects](#check-that-user-cannot-create-other-objects)
        - [Check, that user cannot delete Pods](#check-that-user-cannot-delete-pods)
        - [Check, that user has no access to different namespaces](#check-that-user-has-no-access-to-different-namespaces)
        - [Switch back to default namespace and clean up](#switch-back-to-default-namespace-and-clean-up)
    - [Custom registry](#custom-registry)
        - [Create Azure Container Registry](#create-azure-container-registry)
        - [Push images to registry](#push-images-to-registry)
        - [Run Kubernetes Pod from Azure Container Registry](#run-kubernetes-pod-from-azure-container-registry)
    - [Clean up](#clean-up)

## Switch to our mixed ACS cluster
```
kubectx mojeacsdemo
```

## Create namespace with some Pod
```
kubectl create namespace rbac
kubectl create -f podUbuntu.yaml --namespace rbac
kubectl get pods
kubectl get pods --namespace rbac
```

## Create RBAC credentials and RoleBinding
Provide correct credentials like client-id, tenant-id etc. Also in roleBindingUser1.yaml make sure you replace first UUID with your directory-id (AAD domain id) and after # use id of user being used (in my case id of user1@tomsakubica.cz).
```
. rbacConfig
kubectl config set-credentials "user1@tomaskubica.cz" --auth-provider=azure --auth-provider-arg=environment=AzurePublicCloud --auth-provider-arg=client-id=$clientid --auth-provider-arg=tenant-id=$tenantid --auth-provider-arg=apiserver-id=$apiserverid 

kubectl create -f myrole.yaml
kubectl create -f roleBindingUser1.yaml
```

## Create configuration context and switch to it

```
kubectl config set-context rbac --namespace rbac --cluster mykubeacs --user user1@tomaskubica.cz
kubectl config use-context rbac
```

## Test RBAC
### Make sure user can read Pods
```
kubectl get pods
```

### Make sure user can create Pod
```
kubectl create -f podNetWeb.yaml
```

### Check, that user cannot create other objects
```
kubectl create -f serviceWeb.yaml
```

### Check, that user cannot delete Pods
```
 kubectl delete pod ubuntu
```

### Check, that user has no access to different namespaces
```
kubectl get pods --namespace default
```

### Switch back to default namespace and clean up
```
kubectl config use-context mykubeacs
kubectl delete namespace rbac
```

## Custom registry
### Create Azure Container Registry
```
az group create -n mykuberegistry -l westeurope
az acr create -g mykuberegistry -n tomascontainers --sku Managed_Standard --admin-enabled true
az acr credential show -n tomascontainers -g mykuberegistry
export acrpass=$(az acr credential show -n tomascontainers -g mykuberegistry --query [passwords][0][0].value -o tsv)
```

### Push images to registry
```
docker.exe images
docker.exe tag tkubica/web:1 tomascontainers.azurecr.io/web:1
docker.exe tag tkubica/web:2 tomascontainers.azurecr.io/web:2
docker.exe tag tkubica/web:1 tomascontainers.azurecr.io/private/web:1
docker.exe login -u tomascontainers -p $acrpass tomascontainers.azurecr.io
docker.exe push tomascontainers.azurecr.io/web:1
docker.exe push tomascontainers.azurecr.io/web:2
docker.exe push tomascontainers.azurecr.io/private/web:1
az acr repository list -n tomascontainers -o table
```

### Run Kubernetes Pod from Azure Container Registry
```
kubectl create -f podACR.yaml
```

## Clean up
```
kubectl delete -f clusterRoleBindingUser1.yaml
az group delete -n mykuberegistry -y --no-wait
docker.exe rmi tomascontainers.azurecr.io/web:1
docker.exe rmi tomascontainers.azurecr.io/web:2
docker.exe rmi tomascontainers.azurecr.io/private/web:1

```