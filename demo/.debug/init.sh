#!/bin/bash

set -e
title="mutating-webhook"
namespace="aks-webhook-ns"

echo "create namespace ${namespace}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: aks-webhook-ns
  labels:
    purpose: aks_codeless_attach
    owner: Microsoft
  annotations: 
    environment: testing
EOF

retval=$? 
if [ $retval -ne 0 ]; then
    echo "Error creating namespace"
    exit 1
fi

echo "namespace created"

[ -z ${title} ] && title=mutating-webhook
[ -z ${namespace} ] && namespace=aks-webhook-ns

if [ ! -x "$(command -v dos2unix)" ]; then
    echo "dos2unix not found"
    exit 1
fi

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

csrName=${title}.${namespace}
tmpdir=$(mktemp -d)
echo "creating certs in tmpdir ${tmpdir} "

cat <<EOF >> ${tmpdir}/csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${title}
DNS.2 = ${title}.${namespace}
DNS.3 = ${title}.${namespace}.svc
DNS.4 = ${namespace}.svc
EOF

openssl genrsa -out ${tmpdir}/server-key.pem 2048
openssl req -new -key ${tmpdir}/server-key.pem -subj "/CN=${title}.${namespace}.svc" -out ${tmpdir}/server.csr -config ${tmpdir}/csr.conf

# clean-up any previously created CSR for our service. Ignore errors if not present.
echo "delete previous csr certs if they exist"
kubectl delete csr ${csrName} 2>/dev/null || true

# create server cert/key CSR and send to k8s API
echo "create server cert/key CSR and send to k8s API"
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${csrName}
spec:
  groups:
  - system:authenticated
  request: $(cat ${tmpdir}/server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

# verify CSR has been created
echo "verify CSR has been created"
while true; do
    kubectl get csr ${csrName}
    if [ "$?" -eq 0 ]; then
        break
    fi
done

# approve and fetch the signed certificate
echo "approve and fetch the signed certificate"
kubectl certificate approve ${csrName}
# verify certificate has been signed

for x in $(seq 10); do
    serverCert=$(kubectl get csr ${csrName} -o jsonpath='{.status.certificate}')
    if [[ ${serverCert} != '' ]]; then
        break
    fi
    sleep 1
done
if [[ ${serverCert} == '' ]]; then
    echo "ERROR: After approving csr ${csrName}, the signed certificate did not appear on the resource. Giving up after 10 attempts." >&2
    exit 1
fi
echo ${serverCert} | openssl base64 -d -A -out ${tmpdir}/server-cert.pem

dos2unix ${tmpdir}/server-key.pem
dos2unix ${tmpdir}/server-cert.pem

# create the secret with CA cert and server cert/key
echo "create the secret with CA cert and server cert/key"
kubectl create secret generic ${title} \
        --from-file=key.pem=${tmpdir}/server-key.pem \
        --from-file=cert.pem=${tmpdir}/server-cert.pem \
        --dry-run -o yaml |
    kubectl -n ${namespace} apply -f -

export CA_BUNDLE=$(kubectl get configmap -n kube-system extension-apiserver-authentication -o=jsonpath='{.data.client-ca-file}' | base64 | tr -d '\n')
#cat ./values._aml | envsubst > ./values.yaml

cat <<EOF >> ./values.yaml
namespaces: 
  - target : "<target namespace>" # kubernetes namespace for which to enable codeless attach
    iKey: "<target ikey>" # instrumentation key of Application Insights resource to send telemetry to
  - target : "<target namespace>" # kubernetes namespace for which to enable codeless attach
    iKey: "<target ikey>" # instrumentation key of Application Insights resource to send telemetry to

app:
  caBundle: "${CA_BUNDLE}"
EOF