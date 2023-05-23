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
* Read metrics
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
#### 4. SLO
 
Before running any Chaos Experiments, let's start creating Alerting rules and SLO to measure the health and the efficiency of :
* the K8S cluster
* the Application

##### 1. Efficiency of the Ressource requested at the cluster level:
This Slo would be measure by comparing the Total CPU core usage with the total cpu core requested :
Our SLI would be expressed :
* Total usage/ total requested * 100 because of the nature on how we manage our ressources in k8S, it is possible that the usage could be higher than the request ( if the limit > request)
In Dynatrace we can express the SLI with the following metric expression :
  `((builtin:containers.cpu.usageUserMilliCores:filter(and(or(in("dt.entity.container_group_instance",entitySelector("type(container_group_instance),fromRelationship.isCgiOfCluster(type(KUBERNETES_CLUSTER),entityName.equals(~"sreworshop~"))"))))):splitBy():sum)*(0.001))/(builtin:kubernetes.node.requests_cpu:splitBy():sum)`
#### 2. Efficiency of the ressource requested at the namespace level 
It would be the similar ration except that the cpu core requested and used would be splited by namespace :
`(builtin:kubernetes.workload.cpu_usage:splitBy("k8s.namespace.name"):sort(value(auto,descending)):limit(20))/(builtin:kubernetes.workload.requests_cpu:splitBy("k8s.namespace.name"):sort(value(auto,descending)):limit(20))*(100)`
#### 3. Efficiency of the ressource requested a the workload level
`(builtin:kubernetes.workload.cpu_usage:splitBy("k8s.workload.name"):sort(value(auto,descending)):limit(20))/(builtin:kubernetes.workload.requests_cpu:splitBy("k8s.workload.name"):sort(value(auto,descending)):limit(20))*(100)`

#### 4. SLO on the availabilty of the nodes
We would measure the number of nodes in ready state compared to the total number of nodes available in the cluster.
This SLO would be expressed with the following metric expression:
`
`
#### 6. SLO on the response time of our application
In our example the Hipster-shop has a small K6 load test that acts like a synthetic tests.
THe K6 tests is using the Dynatrace output plugin that is sending all the K6 statistics to Dynatrace.
We could  measure the response time from k6 , with  the following metric expression:
`
`


#### 5.Chaos Experiments

##### 1. Kubernetes settings

The eviction process happens if one of the node is in any of the Pressure conditions :
- DiskPressure
- NodePressure
- NetworkUnavailable
-..
  
In our example we will try to simulate the NodePressure situation.
For this we will use 2 existent experiment available in the ChaosHub of Litmus :
- Node CPU hog
- Node Memory Hog
We will run in parallel on the same node ( having the label node-type=worker) both experiments.
- cpu hog usage : 70%
- memory hog usage : 70%

Let's select one Node from our cluster
```shell
kubectl get ndoes -l node-type=worker
```
Save one of the nodename if the following variable:
```shell
NODE_NAME=<YOUR NODE_NAME>
```
let's update our Chaos experiment with our node name:
```shell
sed -i "s,NODE_NAME_TO_REPLACE,$NODE_NAME,"  litmus chaos/chaos_schedule_nodememoryhog.yaml
```
now we can run the experiment :
```shell
kubectl apply -f litmus chaos/rbac.yaml -n hipster-shop
kubectl apply -f litmus chaos/chaos_schedule_nodememoryhog.yaml 
```

##### 2. Application experiments
To measure the impact of the failure of the important components of the Hipster-shope :
* Redis database
* Productcatalog
TO achieve this we will run first an experiment deleting Redis and then we will run the experiment deleting the product catalog.
```
kubectl apply -f litmus chaos/redis_product.yaml
```
  

#### 6. HPA
To guarantee the godd behavior of our main service , the frontend , let's create a HPA rule that will scale the frontend deploymnet based on the cpu throttling of the frontend container.
By default HPA works with the Kubernetes metric server havinb by default only the CPU and memory usage of the pods.
To extend our current metric server , we will use the Metric Operator deployed with Keptn LifeCycle Toolkit.
For this we need to create:
- a KeptnMetricProvider using the provider type Dynatrace.
- a keptn metric with the right metric expression
```shell
kubectl apply -f keptn/metricProvider.yaml
kubectl apply -f keptn/keptnmetric.yaml
```
Let's have a look a the value reported by in our k8S cluster :
```shell
kubectl get KeptnMetric -n hipster-shop
```

Now that we see a value to our new custom metric , we can deploy our HPA rule :
```shell
kubectl apply -f hipstershop/hpa.yaml -n hipster-shop
```

#### 7. Keptn LifeCycle Toolkit
```shell
kubectl apply -f openTelemetry-demo/deployment.yaml -n otel-demo
```
#### 8. Report the Envoy metrics to Dynatrace using the OpenTelemetry Collector

