# BlueGreen Deployment

**Problem:** "Deploy a sample containerised application on EKS and make it accessible on a https domain.
Envision blue-green deployment of this  application."
   
**Table of Contents**

- [Overview](#overview)
  - [Architecture](#architecture)
- [Installation](#installation)
- [Explanation](#explanation)
  - [SSL](#ssl)
  - [Istio](#istio)
  - [ArgoCD-ArgoRollout](#argocd-argorollout)
  - [HPA.](#hpa)
- [Manual-Bluegreen](#manual-bluegreen)
- [Canary Deployment](#canary-deployment)

## Overview
We devide this problem to 4 parts. 
   1. A sample app to test 
   2. SSL certificate to enforce https 
   3. LoadBalancer/Ingress/ServiceMesh to offload the ssl and Traffic Management
   4. Manual/Tool based solution of deployments and traffic management.
   5. We will be using Istio for service Mesh, ArgoCD and ArgoRollout for Deployment versioning and automated traffic management and can get a free ssl from ssl.com
   
We have 3 repositories: 
   1. [SampleWebApp](https://github.com/tanmayakp/sample-web-app) which contains a sample app written in python. 
   2. [KubeConfigStore](https://github.com/tanmayakp/kube-config-store) which stores the scripts and dependencies to create Kubernetes Objects and install variours  components like istio, argocd etc. 
   3. [GitOpsConfigStore](https://github.com/tanmayakp/gitops-config-store.git) which stores helm charts for our application and the CI tool calculates the diff from here.
   As we can see in the diagram we have an EKS cluster with Istio running. Once we change the image id of the application at [GitOpsConfigStore](https://github.com/tanmayakp/gitops-config-store.git) ArgoCD will detect the change and start deploying the preview rollout. We have two domain www.havefish.ml pointing to active group (green) and preview.havefish.ml pointing to the preview group (blue). Once we are done with the testing we can promote the blue rollout to serve the active traffic. And we can prune the old version.
   We are using GitHub Action for CI. The version mentioned in [version.txt](https://github.com/tanmayakp/sample-web-app/blob/main/version.txt) will be used to create the image name. Ex: v1 is there in version.txt. The image will be tanmayakp/sample-web-app:v1




### Architecture
 ![image](https://user-images.githubusercontent.com/51740283/117567658-aacf3f00-b0da-11eb-9e2d-25c6b23a9717.png)
![image](https://user-images.githubusercontent.com/51740283/117567667-b6226a80-b0da-11eb-815f-bfc4e239fb3d.png)



## Installation

All install scripts are at [KubeConfigStore](https://github.com/tanmayakp/kube-config-store)
The installation steps will install and configure followings:
1.  Run `1.setup-run-istio.sh`. Installs istioctl, istio with default profile, changes LB type to NLB
2.  Run `2.create-app-ns.sh`. Creates a namespace to deploy our app and enables auto sidecar injection.
3.  Run `3.setup-run-argo.sh`. Installs argocd and argo-rollouts.
4.  Run `4.import-cert-as-secret.sh`. Import ssl keys as secret tls type.
5.  Run `5.create-istio-gateway.sh`. Creates `default-gateway` with ssl enabled.
6.  Run `6.create application on argo`. Create 2 application `sample-web-app` (blue-green) and `sample-flask-app` (canary).


> **NOTE**: DNS takes some time to propagate after step 3 which is required to perform step 6

## Explanation

We will go in detail on each component from here.

### SSL

There are multiple choices for the location of SSL offloading. We can offload that at AWS NLB as well as Ingress. Here we are adding it at Service Mesh Gateway level. For that we are creating a  secret of type tls.

`kubectl create -n istio-system secret tls havefish-ssl --key=IstioConfigs/server.key --cert=IstioConfigs/www_havefish_ml.crt`


We can configure 3rd party issuers like letsencrypt or zerossl with the help of `cert-manager` but we are using static certifates for now.
If we are going for 3rd party Ex: letsencrypt here is the steps
1. **Validate your Domain ownership with any DNS provider. (Here we will use ACMEDNS):**

  * Send Request to any acme dns auth provider.
  
  `echo "{\"havefish.ml\": $(curl -s -X POST  https://auth.acme-dns.io/register)}" >> /tmp/acme.json`

  which returns

```json
{
  "havefish.ml": {
    "username": "09862930-b755-4778-8cd2-c9dab9da53cd",
    "password": "R0Rhpe3z0DgH0s22mcEdgp-kDQCEZbhFIFgzzbIV",
    "fulldomain": "80ca8671-f8a2-4d52-a1e7-4c1184b77177.auth.acme-dns.io",
    "subdomain": "80ca8671-f8a2-4d52-a1e7-4c1184b77177",
    "allowfrom": []
  }
}
```
 * create a cname record `_acme-challenge.havefish.ml` resolving to returned `"fulldomain"`. 
 * create a secret with the returned value. 
 
 `kubectl create secret generic acme-dns --from-file /tmp/acme.json`
  
2. **Configure LetsEncrypt as Issuer**

   * using the secret generated in previous step we will create a ClusterIssuer
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: kube-system
spec:
  acme:
    email: tanmaya.cs@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: havefish-ssl
    solvers:
    - dns01:
        acmeDNS:
          host: https://auth.acme-dns.io
          accountSecretRef:
            name: acme-dns
            key: acme.json
```
   
3. **Generate Certificate:**

   * Once the issuer is ready we can request to generate certificate. 
   
```yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: havefish-ssl
  namespace: kube-system
spec:
  commonName: "*.havefish.ml"
  dnsNames:
  - "*.havefish.ml"
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt
  secretName: havefish-ssl
```
  Now our certificate is ready to be ingested to Istio Gateway.



### Istio

We are using default profile of istio where it installs the istio-ingressgateway with AWS Classic Loadbalancer by default. We are changing that to NLB type.

`kubectl annotate svc istio-ingressgateway service.beta.kubernetes.io/aws-load-balancer-type="nlb" -n istio-system`

We are enabling auto sidecar injection to out application pods by annotating the namespace `sample-app`

`kubectl label namespace sample-app istio-injection=enabled`

We are using the secret genereted before on `defalut-gateway`

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: default-gateway
  namespace: default
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
      credentialName: havefish-ssl
      mode: SIMPLE
```

### ArgoCD-ArgoRollout

We are using argo as our CD tool. Argo has its custom crds. Argo follows the gitops process to rollout changes. All the changes are getting version controlled by a repo [GitOpsConfigStore](https://github.com/tanmayakp/gitops-config-store.git). For a new deployment we have to change the image id in at  rollouts/sample-web-app/values.yaml.

Here are few ArgoCD specific Keywords:

`Application` : An unit which maps one gitops path (One helm chart ). 
Ex:

![image](https://user-images.githubusercontent.com/51740283/117567724-fbdf3300-b0da-11eb-80ea-b71f193035aa.png)


Here we can see we are creating one application object which points to the below repo and path (Helm chart)
```yaml
repoURL: https://github.com/tanmayakp/gitops-config-store.git
    targetRevision: HEAD
    path: rollouts/sample-web-app
``` 

`Rollout` : similar to `Deployment`. It is having a spec called strategy wehere we will define whether to do a canary rollout or bluegreen. We are using the type `Rollout` which is at sample-web-app/templates/rollout.yaml

```yaml
spec:
  strategy:
    blueGreen: #Indicates that the rollout should use the BlueGreen strategy
      autoPromotionEnabled: boolean
      activeService: string # sample-web-app
      autoPromotionSeconds: *int32
      antiAffinity: object
      previewService: string # sample-web-app-preview
      prePromotionAnalysis: object
      postPromotionAnalysis: object
      previewReplicaCount: *int32
      scaleDownDelaySeconds: *int32
      scaleDownDelayRevisionLimit: *int32
```

We have kept the auto sync option to false. Once we push our changes it calculates the diff and prepares a rollout plan as per the strategy we have defined. 
![image](https://user-images.githubusercontent.com/51740283/117567736-13b6b700-b0db-11eb-9dd9-ee1c2fa58e76.png)

As we can see one revision is at active and green and the new revision in blue. The virtualservice config at gitops-config-store/rollouts/sample-web-app/values.yaml defines that `preview.havefish.ml` points to the blue one and  `www.havefish.ml` points to the green one. One we do the promotion both will point the active one.
We can promote it by 
`kubectl argo rollouts promote sample-web-app -n sample-app` 
![image](https://user-images.githubusercontent.com/51740283/117567750-229d6980-b0db-11eb-9be0-1209b1ecf11c.png)

After the promotion as you can see the newer revision became active and older revision is getting terminated.

### HPA.
HPA supports resources with the scale endpoint enabled which allows the HPA to understand the current state of a resource and modify the resource to scale it appropriately.
To achive that with argocd we can add this below modification
```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: sample-web-app-hpa
spec:
  maxReplicas: 6
  minReplicas: 2
  scaleTargetRef:
    apiVersion: argoproj.io/v1alpha1
    kind: Rollout
    name: sample-web-app
  targetCPUUtilizationPercentage: 80
```

## Manual-Bluegreen

We can also perform bluegreen deploymnet without using any CD tool. Here we have an example of tha at gitops-config-store/deployments/sample-web-app
```yaml
blueContainer:
    image: tanmayakp/sample-web-app:main-a75a46e
    state: enabled
greenContainer:
    image: tanmayakp/sample-web-app:main-v4
    state: enabled
inactive: green
``` 
We can control the deployment using these parameters. `inactive: green` makes one set inactive by shifting traffic. Making   `state: disabled` will remove those deployments. We can extend this with health check to make desicion over proceeding or rollback. But same functionality has been provided by tools like argocd, spinnaker etc.

## Canary Deployment
Here we have one sample of canary deployment at gitops-config-store/rollouts/sample-flask-app

```yaml
spec:
  strategy:
      canary: #Indicates that the rollout should use the Canary strategy
        maxSurge: "25%" # Can go upto 125% of the replica set.
        maxUnavailable: 0 # Dont delete existing pods.
        steps:
        - setWeight: 10 # 10% of the traffic to canary
        - pause:
            duration: 1h # 1 hour
        - setWeight: 20 # 20% of the traffic to canary
        - pause: {} # pause indefinitely
```
When a new application comes it will deploy canary version of it. and will send 10% traffic to it and will wait for 1h. After 1h it will start sending 20% traffic and will wait for manual promotion. All those behaviours like shall we replace the older instance with canary or we will add over to it, can be controled by various parameters.




