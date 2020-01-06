# Security

When using Kubernetes in secure way there are couple of areas to consider:
- Enterprise identity integration (eg. with AAD) and role-based access control
- Compliance audits and policies (eg. enforcing certain security settings)
- Container security (eg. not running as root)
- Images access and security

Table of Contents:
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
[kubesec.io](kubesec.io) is one of tools to check Kubernetes YAML objects against security best practicies. It is available online (that is what we will use for simplicity), but also downloadable as binary or container to integrate into your CI/CD pipeline.

I have created two Docker images. One running as root and one running as user and pushed to Docker Hub. You can build those yourself and push to your repository:

```bash
cd kubesec/app

# build as root
docker build . -t tkubica/app:root

# build as user
docker build . -t tkubica/app:user -f Dockerfile.user

docker push tkubica/app:root
docker push tkubica/app:user
```

In folder kubesec there are couple of YAMLs starting with not very secure ones and fixing issues found by kubesec as we go. Always make sure result is still deployable and will run properly.

```bash
kubectl apply -f service.yaml
kubectl apply -f app.sec0.yaml
```

Check first attempt.

```bash
curl -X POST --data-binary @app.sec0.yaml https://v2.kubesec.io/scan
```

First fix missing requests (important for efficient scheduling) and limits (important for DoS prevention).

```bash
curl -X POST --data-binary @app.sec1.yaml https://v2.kubesec.io/scan
```

Next fix running as root. Note we need different image build and set non-root user (preferably with high ID number). Also we will make container file system read only which often prevents malware from extracting and persisting.

```bash
curl -X POST --data-binary @app.sec2.yaml https://v2.kubesec.io/scan
```

There are still more Linux capabilities enabled that we need. Eg. we still can do NET_RAW packet processing (such as for ping) for trusted applications with SID flag (such as ping). Should attacker get his application into our image with SID flag (attack container build time) he may get more privilleges. Drop all capabilities and make sure ping no longe works inside container.

```bash
curl -X POST --data-binary @app.sec3.yaml https://v2.kubesec.io/scan
```

In Kubernetes Pods will get default identity (and mount its token to container file system) which does not add any RBAC to cluster. Should attacker trick cluster operator to add permissions to default account atacker cat use container to authanticate to Kubernetes API. Let's that. Add RBAC to default account and from within container try to access Kubernetes API.

```bash
kubectl apply -f clusterRoleForDefaultAccount.yaml

export header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
curl -k -H "$header" https://aks-33zzj5uvr5jfa-736f4ae8.hcp.westeurope.azmk8s.io:443/api/v1/namespaces/default/pods
curl -k -H "$header" https://aks-33zzj5uvr5jfa-736f4ae8.hcp.westeurope.azmk8s.io:443/api/v1/nodes
```

To prevent this accident we will use explicit identity when creating Pod and this identity will not mount token to Pod by default. With this we are using non-default identity, not mounting secrets and also not assign any RBAC to this account.

```bash
kubectl apply -f noaccessAccount.yaml
kubectl delete pod app
kubectl apply -f app.sec4.yaml

curl -X POST --data-binary @app.sec4.yaml https://v2.kubesec.io/scan
```

# Image vulnerability scanning

TODO