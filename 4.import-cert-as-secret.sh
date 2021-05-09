#!/bin/bash

#kubectl create -n istio-system secret tls havefish-creds --key=IstioConfigs/server.key --cert=IstioConfigs/www_havefish_ml.crt
openssl req -x509 -newkey rsa:2048 -subj '/CN=*.havefish.ml'  -keyout IstioConfigs/key.pem -out IstioConfigs/cert.pem -days 365 -nodes

kubectl create -n istio-system secret tls havefish-creds --key=IstioConfigs/key.pem --cert=IstioConfigs/cert.pem