# Basic introduction to world of containers and cloud native

## WebApp with containers as PaaS

Create WebApp for container, Linux version, Python 3.8 PaaS environment

Configure Deploment via local Git, remote build

Clone to PROD folder

Copy files requirements.txt and application.py from src folder, remove app.run statement

Check app is running

Create TEST slot, configure deployment via local Git, remote build a repeat steps to deliver code, but change message to v2.

Test slot swap, A/B testing, canary

## Building custom container and using in WebApp
Create container registry and build container

```bash
az group create -n acr -l westeurope
az acr create -n mojeskvelekontejnery -g acr --sku Standard --admin-enabled
az acr build -r mojeskvelekontejnery --image appka:v1 .
```

Change application code to v2 and build it.

```bash
az acr build -r mojeskvelekontejnery --image appka:v2 .
```

Use GUI to create WebApp with custom container.

s
