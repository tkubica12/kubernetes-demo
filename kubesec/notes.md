# drop capabilities
docker run -it --rm -e PORT=12345 -p 12345:12345 --name app --cap-drop all app

# build as root
docker build . -t tkubica/app:root

# build as user
docker build . -t tkubica/app:user -f Dockerfile.user

docker push tkubica/app:root
docker push tkubica/app:user

kubectl apply -f service.yaml
kubectl apply -f app.sec0.yaml

curl -X POST --data-binary @app.sec0.yaml https://v2.kubesec.io/scan
curl -X POST --data-binary @app.sec1.yaml https://v2.kubesec.io/scan
curl -X POST --data-binary @app.sec2.yaml https://v2.kubesec.io/scan
curl -X POST --data-binary @app.sec3.yaml https://v2.kubesec.io/scan

# No ServiceAccount token
kubectl apply -f clusterRoleForDefaultAccount.yaml

export header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
curl -k -H "$header" https://aks-33zzj5uvr5jfa-736f4ae8.hcp.westeurope.azmk8s.io:443/api/v1/namespaces/default/pods
curl -k -H "$header" https://aks-33zzj5uvr5jfa-736f4ae8.hcp.westeurope.azmk8s.io:443/api/v1/nodes

kubectl apply -f noaccessAccount.yaml
kubectl delete pod app
kubectl apply -f app.sec3.yaml