#!/bin/bash

# Get NLB host and Argo admin Password
echo "Argo Host"
ARGO_NLB_HOST=$(kubectl get svc -n istio-system argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ARGO_NLB_HOST
echo "Argo Password"
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGO_PASSWORD

