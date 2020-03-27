# Demo environment via GitHub Actions
This demo uses GitHub Actions to orchestrate deployment of infrastructure, application build and applicatio deployment.
1. Terraform is used to deploy AKS cluster (including monitoring, policy engine and AAD integration), Application Gateway (WAF), PostgreSQL as a Service, Key Vault and other infrastructure components
2. Helm is used to deploy base AKS cluster components such as Ingress controller for App Gw, KEDA, Grafana, Prometheus
3. Azure Container Registry is used to build and package todo application
4. Helm is used to deploy application to cluster and expose via ingress

# Included compontents
Currently covered
- Azure Kubernetes Service
- Azure Container Registry
- AKS AAD integration with RBAC
- Azure Application Gateway Web Application Firewall as Ingress
- Azure Monitor for Containers including Prometheus scrapper
- Azure Database for PostgreSQL
- Azure Event Hub
- Azure Blob Storage
- Azure Service Bus
- Grafana with Azure Monitor datasource
- Prometheus
- Windows nodes

Planned
- DAPR
- RUDP
- Linkerd
- Flagger
- AAD Pod Identity
- Key Vault FlexVolume
- Azure CosmosDB

# After deployment
Check application running on demo.tomaskubica.in

Check AAD integration
```bash
rm ~/.kube/config
az aks get-credentials -n tomasdemoaks-test -g aks-test
kubectl get nodes   # login as admin@tomaskubicaoffice.onmicrosoft.com
```

Check ASC recommendations for ACR and AKS

Check policy engine in Azure Policy



# Manual testing
## Install Terraform
```bash
wget https://releases.hashicorp.com/terraform/0.12.21/terraform_0.12.21_linux_amd64.zip
unzip terraform_0.12.21_linux_amd64.zip
chmod +x ./terraform
sudo mv ./terraform /usr/bin
```

## Deploy via Terraform
```bash
cd demo/
source .secrets
terraform init
terraform plan
terraform apply -auto-approve
```
