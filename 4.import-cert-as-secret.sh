#!/bin/bash

### Self signed certificate
openssl req -x509 -newkey rsa:2048 -subj '/CN=*.havefish.ml'  -keyout IstioConfigs/key.pem -out IstioConfigs/cert.pem -days 365 -nodes
kubectl create -n istio-system secret tls havefish-ssl --key=IstioConfigs/key.pem --cert=IstioConfigs/cert.pem

### Paid/Free thirdparty certificate
#openssl req -new -newkey rsa:2048 -nodes -keyout server.key -out server.csr
### Generate certificate from CSR
#kubectl create -n istio-system secret tls havefish-creds --key=IstioConfigs/server.key --cert=IstioConfigs/www_havefish_ml.crt


### LetsEncrypt Free SSL 

# echo "{"havefish.ml": $(curl -s -X POST  https://auth.acme-dns.io/register)}" > /tmp/acme.json



# kubectl create secret generic acme-dns --from-file /tmp/acme.json

# kubectl apply -f - <<EOF
# apiVersion: cert-manager.io/v1
# kind: ClusterIssuer
# metadata:
#   name: letsencrypt
#   namespace: kube-system
# spec:
#   acme:
#     email: tanmaya.cs@gmail.com
#     server: https://acme-v02.api.letsencrypt.org/directory
#     privateKeySecretRef:
#       name: havefish-ssl
#     solvers:
#     - dns01:
#         acmeDNS:
#           host: https://auth.acme-dns.io
#           accountSecretRef:
#             name: acme-dns
#             key: acme.json
# EOF

# kubectl apply -f - <<EOF
# apiVersion: cert-manager.io/v1alpha2
# kind: Certificate
# metadata:
#   name: havefish-ssl
#   namespace: kube-system
# spec:
#   commonName: "*.havefish.ml"
#   dnsNames:
#   - "*.havefish.ml"
#   issuerRef:
#     kind: ClusterIssuer
#     name: letsencrypt
#   secretName: havefish-ssl
# EOF




