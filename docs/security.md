# Security

When using Kubernetes in secure way there are couple of areas to consider:
- Enterprise identity integration (eg. with AAD) and role-based access control
- Compliance audits and policies (eg. enforcing certain security settings)
- Container security (eg. not running as root)
- Images access and security

- [Security](#security)
- [Namespaces](#namespaces)
- [Authenticating with Azure Active Directory](#authenticating-with-azure-active-directory)
- [Authorizing AAD users](#authorizing-aad-users)
- [Using private image registry](#using-private-image-registry)
  - [Create Azure Container Registry](#create-azure-container-registry)
  - [Push images to registry](#push-images-to-registry)
  - [Run Kubernetes Pod from Azure Container Registry](#run-kubernetes-pod-from-azure-container-registry)
  - [Clean up](#clean-up)
- [AAD Pod Identity to access Azure resources](#aad-pod-identity-to-access-azure-resources)
- [Checking security best practices with Kubesec](#checking-security-best-practices-with-kubesec)
- [Image vulnerability scanning](#image-vulnerability-scanning)

# Namespaces
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

# Authenticating with Azure Active Directory
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

# Authorizing AAD users
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

# AAD Pod Identity to access Azure resources
Azure supports Managed Service Identity to provide secure way for applications to get AAD tokens. MSI is designed for VMs and Azure App Services, but with AKS such granularity is not enough. We need mechanism to manage such access on per-pod basis. This is solved with AAD Pod Identity.

First install AAD Pod Identity.

```bash
kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
```

Next we will create one or more managed identities - AAD service principal accounts with lifecycle managed throw Azure Resource Manager and with no secret (account will be used only via AAD Pod Identity to get tokens, will not be available for anything outside this system). AKS needs to have Managed Identity Operator rights for this identity, which is by default available in AKS resources group (such as MC_...). You can create identity in that resource group or in other one if you grant Managed Identity Operator role for your AKS principal.

```bash
az identity create -g aks -n myaccount1
```

Prepare AzureIdenity YAML definition. We will use namespaced object.

```bash
cat > identity1.yaml << EOF
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: identity1
  annotations:
    aadpodidentity.k8s.io/Behavior: namespaced
spec:
  type: 0
  ResourceID: $(az identity show -g aks -n myaccount1 --query id -o tsv)
  ClientID: $(az identity show -g aks -n myaccount1 --query clientId -o tsv)
EOF
```

Let's now create AzureIdentity and also apply AzureIdentityBinding to one namespace. AAD Pod Identity is using labels to select what identity is available in what Pod. In our example we will use selector identity1.

```bash
kubectl create namespace app1
kubectl apply -f identity1.yaml -n app1
kubectl apply -f identity1Binding.yaml -n app1
```

Create Pod with label identity1 to associate it with identity.

```bash
kubectl apply -f podIdentity.yaml -n app1
```

We can now use MSI endpoint to get access token.

```bash
kubectl exec -ti mybox -n app1 -- curl http://169.254.169.254/metadata/identity/oauth2/token?resource=https://management.azure.com
```

We have got AAD token. Our identity at this point has no RBAC associated, but we can give it access to Azure resources as use this token to make ARM API calls. You might also want to generate token for different resources such as Azure Key Vault.

# Checking security best practices with Kubesec

TODO

# Image vulnerability scanning

TODO