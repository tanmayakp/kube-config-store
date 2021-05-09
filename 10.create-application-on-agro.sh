#!/bin/bash

# Get NLB host and Argo admin Password
ARGO_NLB_HOST=$(kubectl get svc -n istio-system argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ARGO_NLB_HOST
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGO_PASSWORD

# Login from local
argocd login $ARGO_NLB_HOST --username admin --password $ARGO_PASSWORD --insecure

echo "Creating Bluegreen Deployable App"
kubectl apply -f ArgoConfigs/sample-application-bluegreen.yaml

echo "Creating Canary Deployable App"
kubectl apply -f ArgoConfigs/sample-application-canary.yaml

# argocd app sync sample-web-app
# argocd app sync sample-flask-app

