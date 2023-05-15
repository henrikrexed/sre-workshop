#  SRE Workshop with Dynatrace
This repository contains the files required for the SRE Workshop

This repository showcase the usage of several solutions :
* the HipsterShop
* Litmus Chaos
* OpenTelemetry Collector
* Istio
* Keptn LifeCycle Controller
* THe OpenTelemetry Demo application


In this workshop we will walk through the usage of Configuring The Keptn LifeCycle Toolkit to deploy
- the hipster-shop
- the OpenTelemetry demo Application.

During this workshop we will learn how to :
- Configure Chaos Experiments 
- Create SLO to keep track on the health of our OpenTelemetry Collectors

## Prerequisite 
The following tools need to be install on your machine :
- jq
- kubectl
- git
- gcloud ( if you are using GKE)
- Helm

### 1.Create a Google Cloud Platform Project
```shell
PROJECT_ID="<your-project-id>"
gcloud services enable container.googleapis.com --project ${PROJECT_ID}
gcloud services enable monitoring.googleapis.com \
cloudtrace.googleapis.com \
clouddebugger.googleapis.com \
cloudprofiler.googleapis.com \
--project ${PROJECT_ID}
```
### 2.Create a GKE cluster
```shell
ZONE=europe-west3-a
NAME=sreworshop
gcloud container clusters create ${NAME} --zone=${ZONE} --machine-type=e2-standard-8 --num-nodes=3
```
### 3.Clone Github repo
```shell
git clone https://github.com/henrikrexed/sre-workshop
cd sre-workshop
```
### 4. Deploy 

#### 0. Label Nodes
kubectl get nodes -o wide
kubectl label <nodename1> node-type=observability
kubectl label <nodename2> node-type=worker
kubectl label <nodename3> node-type=worker

#### 1. Istio

1. Download Istioctl
```shell
curl -L https://istio.io/downloadIstio | sh -
```
This command download the latest version of istio ( in our case istio 1.17.2) compatible with our operating system.
2. Add istioctl to you PATH
```shell
cd istio-1.17.2
```
this directory contains samples with addons . We will refer to it later.
```shell
export PATH=$PWD/bin:$PATH
```

#### 1. Install Istio
To enable Istio and take advantage of the tracing capabilities of Istio, you need to install istio with the following settings
 ```shell
istioctl install --set meshConfig.accessLogFile=/dev/stdout --set meshConfig.enableTracing=true --set profile=demo -y
 ```


#### 2. Dynatrace 
##### 1. Dynatrace Tenant - start a trial
If you don't have any Dyntrace tenant , then i suggest to create a trial using the following link : [Dynatrace Trial](https://bit.ly/3KxWDvY)
Once you have your Tenant save the Dynatrace (including https) tenant URL in the variable `DT_TENANT_URL` (for example : https://dedededfrf.live.dynatrace.com)
```shell
DT_TENANT_URL=<YOUR TENANT URL>
```
##### 2. Create the Dynatrace API Tokens
The dynatrace operator will require to have several tokens:
* Token to deploy and configure the various components
* Token to ingest metrics and Traces


###### Operator Token
One for the operator having the following scope:
* Create ActiveGate tokens
* Read entities
* Read Settings
* Write Settings
* Access problem and event feed, metrics and topology
* Read configuration
* Write configuration
* Paas integration - installer downloader
<p align="center"><img src="/image/operator_token.png" width="40%" alt="operator token" /></p>

Save the value of the token . We will use it later to store in a k8S secret
```shell
API_TOKEN=<YOUR TOKEN VALUE>
```
###### Ingest data token
Create a Dynatrace token with the following scope:
* Ingest metrics (metrics.ingest)
* Ingest logs (logs.ingest)
* Ingest events (events.ingest)
* Ingest OpenTelemtry
<p align="center"><img src="/image/data_ingest_token.png" width="40%" alt="data token" /></p>
Save the value of the token . We will use it later to store in a k8S secret

```shell
DATA_INGEST_TOKEN=<YOUR TOKEN VALUE>
```
#### 3. Run the deployment script
```shell
cd ..
chmod 777 deployment.sh
./deployment.sh  --clustername "${NAME}" --dturl "${DT_TENANT_URL}" --dtoperatortoken "${API_TOKEN}" --dtingesttoken "${DATA_INGEST_TOKEN}" 
```




