# Demo environment via GitHub Actions
This demo uses GitHub Actions to orchestrate deployment of infrastructure, application build and applicatio deployment.
1. Terraform is used to deploy AKS cluster (including monitoring, policy engine and AAD integration), Application Gateway (WAF), PostgreSQL as a Service, Key Vault, Service Bus, Event Hub and other infrastructure components. **In main.tf check what variables are needed and store them in your GitHub secrets to fit your environment**
2. AKS and its components (AAD Pod Identity, Application Gateway Ingress controller, Key Vault FlexVolume) are configured for ManagedIdentity (no Service Principal)
3. Helm is used to deploy base AKS cluster components such as Ingress controller for App Gw, DAPR, KEDA, Grafana, Prometheus
4. Azure Container Registry is used to build and package applications
5. DNS record cloud.tomaskubica.in and *.cloud.tomaskubica.in is preconfigured with CNAME pointing to App Gw public IP - only thing that is done outside of Actions. **You need to change this to fit your environment**

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
Check telemetry and distributed tracing gathered in Application Insights (appid-blabla workspace) - codeless attach is used (no built-in support in app itself)
FlexVolume is used to pass PostgreSQL secrets from Key Vault
Check Prometheus telemetry gathered in Prometheus at prometheus.cloud.tomaskubica.in
Check Grafana dashboards and grafana.cloud.tomaskubica.in:
    - AKS cluster dashboard
    - Prometheus telemetry via Prometheus
    - Prometheus telemetry via Azure Monitor backend
Check Prometheus telemetry scrapped in Azure Monitor

## DAPR and KEDA
DAPR and KEDA components are deployed in dapr and keda namespaces. KEDA is configured to leverage AAD Pod Identity for authentication to Service Bus. DAPR currently does not offer this for Service Bus component, but AAD pod identity is used for accessing Key Vault secrets.

Store and retrieve state

```bash
kubectl exec -ti nodea-0 -n dapr-demo -- bash /home/user/write.sh
kubectl exec -ti nodeb-0 -n dapr-demo -- bash /home/user/read.sh
```

DAPR is configured to enable messaging between services using Service Bus backend. Connect to nodea-0 and use curl to send message to DAPR. Deployment subscribeorders will receive message. Also look into Service Bus in portal to see subscriber has been created in orders topic.

```bash
kubectl exec -ti nodea-0 -n dapr-demo -- bash /home/user/createorder.sh
kubectl logs -l app=subscribeorders -n dapr-demo -c container
```

Service bindingservicebus is configured with binding to DAPR events from Service Bus queue binding. There is KEDA scaling bounded to this queue so you should not see any Pods running. Go to nodea to generate 20 messages and whats Pods being created to deal with load.

```bash
kubectl exec -ti nodea-0 -n dapr-demo -- python /home/user/sendMessagesToServiceBus.py
```

DAPR provides Blob Storage output binding for nodea. Check it out.

```bash
kubectl exec -ti nodea-0 -n dapr-demo -- bash /home/user/blobout.sh myOutFile.json
```

DAPR Secrets API is configured to point to Azure Key Vault. Use DAPR API to read secrets.

```bash
kubectl exec -ti nodea-0 -n dapr-demo -- bash /home/user/getsecret.sh
```

Service cart comes with /add API call of type POST. You can use DAPR sidecar to call other services.

```bash
kubectl exec -ti nodea-0 -n dapr-demo -- bash /home/user/add.sh
```

Grafana demo install has some Dashboards defined connected to Prometheus.
Find it at https://grafana.cloud.tomaskubica.in

Telemetry and logs are also gathered to Azure Monitor.

## Windows nodes
Basic IIS instance is accessible at iis.cloud.tomaskubica.in and runs in windows namespace.



