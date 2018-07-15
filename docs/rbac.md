# Operational security with RBAC, Azure Active Directory, namespaces and Azure Container Registry

When using Kubernetes in enterprise there might be need to role based access control and strong authentication. In this demo we will see how to to use namespaces in Kubernetes to isolate resources from control plane level, how to authenticate user with strong Azure Active Directory authentication and how to authorize what each user can do with Kubernetes RBAC. Also we will look into private registry, how to secure it and make sure company provided images are used.

- [Operational security with RBAC, Azure Active Directory, namespaces and Azure Container Registry](#operational-security-with-rbac-azure-active-directory-namespaces-and-azure-container-registry)
- [Role-based access control, Azure Active Directory and Kubernetes Namespaces](#role-based-access-control-azure-active-directory-and-kubernetes-namespaces)
    - [Namespaces](#namespaces)
    - [Authenticating with Azure Active Directory](#authenticating-with-azure-active-directory)
    - [Authorizing AAD users](#authorizing-aad-users)
- [Using private image registry](#using-private-image-registry)
    - [Create Azure Container Registry](#create-azure-container-registry)
    - [Push images to registry](#push-images-to-registry)
    - [Run Kubernetes Pod from Azure Container Registry](#run-kubernetes-pod-from-azure-container-registry)
    - [Clean up](#clean-up)

# Role-based access control, Azure Active Directory and Kubernetes Namespaces
In this section we will explore namespaces that can group Kubernetes objects and role-based access control to manage what users or service accounts can do with the system.

## Namespaces
When you create Namespace in Kubernetes you can deploy objects (Pods, Services, Deployments, Secrets, ...) into it and make it easier to manage multiple projects or environments in single cluster:
* User explicitely need to select namespace or actively switch context so accidental damage to all environments with single command is not possible
* Services are available in local namespace just using their names yet still you can use DNS between namespaces when you query more complete name (eg. you can have service "auth" in both staging and production environment accessible within namespace via auth name, yet when you explicitely ask for auth.prod you can get there from staging namespace)
* Namespaces are good scope for RBAC (eg. dev staff has full access to testing env, but read only for prod)
* You can easily destroy namespace with all its object so it is good for personal Dev environments 

Let's create name space and deploy Pod to it.

```
kubectl create namespace rbac
kubectl create -f podUbuntu.yaml -n rbac
kubectl get pods
kubectl get pods -n rbac
```

## Authenticating with Azure Active Directory
We have build our AKS cluster with AAD integration. We can easily create context for AAD users by typing:

```
az aks get-credentials -n akscluster -g aksgroup
kubectl config use-context akscluster
```

Let's now try to log in with AAD. Type any kubectl command and you will be prompted for login via browser (so all AAD functionality will work including MFA or conditional access). Please note that we will authenticate OK, but there is no authorization yet so you cannot access any resources.

```
kubectl get pods -n rbac
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code CEH84ZR99 to authenticate.
```

## Authorizing AAD users
When logged in as AAD user we are not authorized to do anything in our cluster. If this is administrator you can use built-in administrator role and than user cluster binding for AAD user  (this will add full rights to all namespaces). In our example we will consider this limited user. We will create new custom role that get access to working with Pods, Services and Deployments, but not other types of resources (Ingress, Secrets etc.). We wil grant trhis level of access only to one namespace - therefore we will use role binding to specific namespace.

```
kubectl config use-context akscluster-admin
kubectl create -f role.yaml
kubectl create -f roleBindingUser1.yaml
```

In order to troubleshoot this you can check authorization settings easily using admin account.

```
kubectl auth can-i get pods --as=user1@tomaskubica.cz
kubectl auth can-i get pods --as=user1@tomaskubica.cz -n rbac
```

Test it out. Log in as AAD user and make sure you can access Pods only in rbac namespace and cannot access Secrets even in rbac namespace.

```
kubectl config use-context akscluster
kubectl get pods
kubectl get pods -n rbac
kubectl get secrets -n rbac
```

It is not very comfortable having to specify namespace with every command especially when you have no access to default namespace anyway. You can configure new context with different default namespace.

```
kubectl config set-context user1 \
    --user clusterUser_aksgroup_akscluster \
    --cluster akscluster \
    --namespace rbac
kubectl config use-context user1
kubectl get pods
```
Note that you can also bind roles to AAD Groups.

# Using private image registry

**TO DO: more documentation and context
TO DO: build as a service**

## Create Azure Container Registry
```
az group create -n mykuberegistry -l westeurope
az acr create -g mykuberegistry -n tomascontainers --sku Managed_Standard --admin-enabled true
az acr credential show -n tomascontainers -g mykuberegistry
export acrpass=$(az acr credential show -n tomascontainers -g mykuberegistry --query [passwords][0][0].value -o tsv)
```

## Push images to registry
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

## Run Kubernetes Pod from Azure Container Registry
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