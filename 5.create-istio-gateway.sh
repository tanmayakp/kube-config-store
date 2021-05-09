#!/bin/bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: default-gateway
  namespace: sample-app
spec:
  selector:
    istio: ingressgateway 
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
    tls:
      httpsRedirect: false 
  - port:
      name: https-default
      number: 443
      protocol: HTTPS
    hosts:
      - '*'
    tls:
      credentialName: havefish-creds
      mode: SIMPLE
EOF