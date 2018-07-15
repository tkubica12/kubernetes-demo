# Kubernetes in Azure
This repo contains my Kubernetes demo in Azure.

# Recently added (July 2018)
* AKS GA updates
* ConfigMaps and Secrets
* Sigterm
* Liveness and readiness probes
* Session affinity
* Init containers
* Multi-process containers, multi-container Pods and pod affinity
* Canary releases with multiple Deployments under single Service
* Headless services
* Services with no selector
* Ingress with cert-manager to auto-enroll letsencrypt certificates
* Ingress session cookie persistence
* Ingress rate limit
* Ingress custom errors
* Ingress Basic Authentication
* Ingress authentication against Azure Active Directory
* Persistent Volumes with Azure Files
* StatefulSet demo with headless Service, PostgreSQL, backup CronJob
* RBAC with Azure Active Directory

# TO DO
* HPA scaling with metrics from Prometheus such as requests per second
* Upgrade to latest Istio
* Upgrade to latest Draft
* Building custom Charts with Helm
* Kubernetes federation
* AKS cluster upgrade demo
* VSTS integration
* Spinnaker integration
* Brigade

# Table of Contents
- [Deploying managed Kubernetes (AKS)](docs/aks-build.md)
- [Building custom unmanaged ACS cluster](docs/acs-build.md)
- [Deploying apps with Pods, Deployments and Services](docs/apps.md)
- [Passing secrets and configurations to Pods](docs/configurations.md)
- [Stateful applications and StatefulSet with Persistent Volume](docs/stateful.md)
- [Advanced networking with Ingress (L7 proxy) and network policy](docs/networking.md)
- [Scaling your apps and cluster](docs/scaling.md)
- [Operational security with RBAC, Azure Active Directory, namespaces and Azure Container Registry](docs/rbac.md)
- [Azure Container Instances and serverless containers with Virtual Kubelet](docs/aci.md)
- [Package applications with Helm](docs/helm.md)
- [Develop apps on Kubernetes with Draft](docs/draft.md)
- [Deploy CI/CD with Jenkins and agents in containers](docs/jenkins.md)
- [Creating service mesh with Istio](docs/istio.md)
- [Automatically provision Azure services with Service Catalog](docs/servicecatalog.md)
- [Monitoring](docs/monitoring.md)


# Author
Tomas Kubica, linkedin.com/in/tkubica, Twittter: @tkubica

Blog in Czech: https://tomaskubica.cz

Looking forward for your feedback and suggestions!