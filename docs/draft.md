- [Draft](#draft)
    - [Install Traefik and create DNS entry](#install-traefik-and-create-dns-entry)
    - [Install Draft](#install-draft)
    - [Run](#run)

**This section has not yet been updated for AKS**


# Draft
## Install Traefik and create DNS entry
```
helm fetch --untar stable/traefik
```
Modify deployment template to deploy to linuxpool:
```
      nodeSelector:
        agentpool: linuxpool
```
```
cd traefik
helm install . --name ingress
kubectl get service ingress-traefik
export draftip=$(kubectl get service ingress-traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export oldip=$(az network dns record-set a show -n *.draft -g shared-services -z azure.tomaskubica.cz --query arecords[0].ipv4Address -o tsv)
az network dns record-set a remove-record -a $oldip -n *.draft -g shared-services -z azure.tomaskubica.cz
az network dns record-set a add-record -n *.draft -a $draftip -g shared-services -z azure.tomaskubica.cz
```

## Install Draft
```
wget https://github.com/Azure/draft/releases/download/v0.7.0/draft-v0.7.0-linux-amd64.tar.gz
tar -xvf draft-v0.7.0-linux-amd64.tar.gz
sudo mv linux-amd64/draft /usr/bin/

cd nodeapp
draft create
```

## Run
```
cd nodeapp
draft up
draft connect
```