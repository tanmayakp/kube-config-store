#!/bin/bash

# Get istioctl Binary

PWD=$(pwd)
cd /tmp
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.0 sh -
sudo cp istio-1.9.0/bin/istioctl /usr/local/bin/
sudo chmod +x /usr/local/bin/istioctl
cd $PWD

# Install Istio
kubectl create namespace istio-system
istioctl install --set profile=default  --set hub=gcr.io/istio-release -y

# Verify
kubectl get pods -n istio-system
kubectl get svc -n istio-system

# convert the LB type to NLB
kubectl annotate svc istio-ingressgateway service.beta.kubernetes.io/aws-load-balancer-type="nlb" -n istio-system

# Adding DashBoards
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/extras/zipkin.yaml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml

