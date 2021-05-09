#!/bin/bash

kubectl create -n istio-system secret tls havefish-creds --key=IstioConfigs/server.key --cert=IstioConfigs/www_havefish_ml.crt
