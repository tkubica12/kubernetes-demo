- [Install RUDR](#install-rudr)
- [As infrastructure operator install Ingress and KEDA](#as-infrastructure-operator-install-ingress-and-keda)
- [As developer declare component schematic](#as-developer-declare-component-schematic)
- [As application operator define instance details and deploy](#as-application-operator-define-instance-details-and-deploy)
- [Cleanup](#cleanup)

# Install RUDR
git clone https://github.com/oam-dev/rudr.git

helm install rudr rudr/charts/rudr --wait --set image.tag=latest

# As infrastructure operator install Ingress and KEDA
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update
helm install nginx-ingress stable/nginx-ingress

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create namespace keda
helm install keda kedacore/keda --namespace keda 

# As developer declare component schematic
kubectl apply -f components.yaml
kubectl get componentschematic

# As application operator define instance details and deploy
kubectl apply -f applicationConfig.yaml

# Cleanup
kubectl delete -f applicationConfig.yaml
kubectl delete -f components.yaml
helm delete rudr