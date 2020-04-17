# Demo environment via GitHub Actions
This demo uses GitHub Actions to orchestrate deployment of infrastructure, application build and applicatio deployment.
1. Terraform is used to deploy AKS cluster (including monitoring, policy engine and AAD integration), Application Gateway (WAF), PostgreSQL as a Service, Key Vault, Service Bus, Event Hub and other infrastructure components
2. AKS and its components (AAD Pod Identity, Application Gateway Ingress controller, Key Vault FlexVolume) are configured for ManagedIdentity (no Service Principal)
3. Helm is used to deploy base AKS cluster components such as Ingress controller for App Gw, DAPR, KEDA, Grafana, Prometheus
4. Azure Container Registry is used to build and package applications
5. DNS record cloud.tomaskubica.in and *.cloud.tomaskubica.in is preconfigured with CNAME pointing to App Gw public IP - only thing that is done outside of Actions

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
- DAPR
- AAD Pod Identity
- Key Vault FlexVolume

Planned
- RUDR
- Linkerd
- Flagger
- Azure CosmosDB

# Demonstrations
## Cluster operations
Check AAD integration

```bash
rm ~/.kube/config
az aks get-credentials -n tomasdemoaks-test -g aks-test
kubectl get nodes   # login as admin@tomaskubicaoffice.onmicrosoft.com
```

Check ASC recommendations for ACR and AKS

Check policy engine in Azure Policy

## Todo applicaiton
Access todo application at cloud.tomaskubica.in (Ingress via Application Gateway)
Check telemetry gathered in Application Insights (appid-blabla workspace) - codeless attach is used (no built-in support in app itself)
FlexVolume is used to pass PostgreSQL secrets from Key Vault
Check Prometheus telemetry gathered in Prometheus at prometheus.cloud.tomaskubica.in
Check Grafana dashboards and grafana.cloud.tomaskubica.in:
    - AKS cluster dashboard
    - Prometheus telemetry via Prometheus
    - Prometheus telemetry via Azure Monitor backend
Check Prometheus telemetry scrapped in Azure Monitor

## DAPR and KEDA
TBD

## Windows nodes
Basic IIS instance is accessible at iis.cloud.tomaskubica.in



