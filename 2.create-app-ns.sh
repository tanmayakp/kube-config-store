#!/bin/bash


# Enable Auto injection
kubectl create ns sample-app
kubectl label namespace sample-app istio-injection=enabled