#!/usr/bin/env bash

################################################################################
### Script deploying the Observ-K8s environment
### Parameters:
### Clustern name: name of your k8s cluster
### dttoken: Dynatrace api token with ingest metrics and otlp ingest scope
### dturl : url of your DT tenant wihtout any / at the end for example: https://dedede.live.dynatrace.com
################################################################################


### Pre-flight checks for dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "Please install jq before continuing"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Please install git before continuing"
    exit 1
fi


if ! command -v helm >/dev/null 2>&1; then
    echo "Please install helm before continuing"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Please install kubectl before continuing"
    exit 1
fi
echo "parsing arguments"
while [ $# -gt 0 ]; do
  case "$1" in
  --dtoperatortoken)
    DTOPERATORTOKEN="$2"
   shift 2
    ;;
  --dtingesttoken)
    DTTOKEN="$2"
   shift 2
    ;;
  --dturl)
    DTURL="$2"
   shift 2
    ;;
  --clustername)
    CLUSTERNAME="$2"
   shift 2
    ;;
  *)
    echo "Warning: skipping unsupported option: $1"
    shift
    ;;
  esac
done
echo "Checking arguments"
if [ -z "$CLUSTERNAME" ]; then
  echo "Error: clustername not set!"
  exit 1
fi
if [ -z "$DTURL" ]; then
  echo "Error: Dt url not set!"
  exit 1
fi

if [ -z "$DTTOKEN" ]; then
  echo "Error: Data ingest api-token not set!"
  exit 1
fi

if [ -z "$DTOPERATORTOKEN" ]; then
  echo "Error: DT operator token not set!"
  exit 1
fi



### get the ip adress of ingress ####
IP=""
while [ -z $IP ]; do
  echo "Waiting for external IP"
  IP=$(kubectl get svc istio-ingressgateway -n istio-system -ojson | jq -j '.status.loadBalancer.ingress[].ip')
  [ -z "$IP" ] && sleep 10
done
echo 'Found external IP: '$IP

### Update the ip of the ip adress for the ingres
#TODO to update this part to create the various Gateway rules
sed -i "s,IP_TO_REPLACE,$IP," istio/istio_gateway.yaml


### Depploy Prometheus

#### Deploy the cert-manager & the openTelemetry Operator
echo "Deploying Cert Manager ( for OpenTelemetry Operator)"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.yaml
# Wait for pod webhook started
kubectl wait pod -l app.kubernetes.io/component=webhook -n cert-manager --for=condition=Ready --timeout=2m
# Deploy the opentelemetry operator
sleep 10
echo "Deploying the OpenTelemetry Operator"
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
#### Deploy kepn lifecycle Toolkit
helm repo add klt https://charts.lifecycle.keptn.sh
helm repo update
helm upgrade --install keptn klt/klt -n keptn-lifecycle-toolkit-system --create-namespace --wait

#### Deploy Litmus
kubectl create ns litmus
helm install chaos litmuschaos/litmus --namespace=litmus --set upgradeAgent.nodeSelector.node-type=observability	 --set portal.server.nodeSelector.node-type=observability --set portal.frontend.nodeSelector.node-type=observability  --set mongo.nodeSelector.node-type=observability

#### Deploy the Dynatrace Operator
kubectl create namespace dynatrace
kubectl apply -f https://github.com/Dynatrace/dynatrace-operator/releases/download/v0.11.1/kubernetes.yaml
kubectl apply -f https://github.com/Dynatrace/dynatrace-operator/releases/download/v0.11.1/kubernetes-csi.yaml
kubectl -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook --timeout=300s
kubectl -n dynatrace create secret generic dynakube --from-literal="apiToken=$DTOPERATORTOKEN" --from-literal="dataIngestToken=$DTTOKEN"
sed -i "s,TENANTURL_TOREPLACE,$DTURL," dynatrace/dynakube.yaml
sed -i "s,CLUSTER_NAME_TO_REPLACE,$CLUSTERNAME,"  dynatrace/dynakube.yaml
sed -i "s,TENANTURL_TOREPLACE,$DTURL," keptn/metricProvider.yaml
kubectl apply -f dynatrace/dynakube.yaml -n dynatrace

# Deploy collector
kubectl create secret generic dynatrace  --from-literal=dynatrace_oltp_url="$DTURL" --from-literal=dt_api_token="$DTTOKEN"
kubectl apply -f openTelemetry-demo/openTelemetry-manifest_debut.yaml

# Echo environ*
#deploy demo application
kubectl create ns hipster-shop
kubectl create secret generic dynatrace  --from-literal=dynatrace_oltp_url="$DTURL" --from-literal=dt_api_token="$DTTOKEN" -n hipster-shop
kubectl label namespace hipster-shop istio-injection=enabled
kubectl apply -f hipstershop/k8s-manifest.yaml -n hipster-shop

## Deploy the otel demo
kubectl create ns otel-demo
kubectl create secret generic dynatrace  --from-literal=dynatrace_oltp_url="$DTURL" --from-literal=dt_api_token="$DTTOKEN" -n otel-demo
kubectl label namespace otel-demo oneagent=false
kubectl label namespace otel-demo istio-injection=enabled
kubectl annotate ns otel-demo  keptn.sh/lifecycle-toolkit="enabled"
kubectl apply -f openTelemetry-demo/openTelemetry-sidecar.yaml -n otel-demo
#Deploy the Keptn predployment Tasks
kubectl apply -f keptn/keptnconfig.yaml
kubectl apply -f keptn/keptn-predeployment_adservice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_cartservice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_checkoutservice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_currency.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_featureflag.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_frontend.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_kafka.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_paymentservice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_postgres.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_productcatalogserice.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_recommendation.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_redis.yaml -n otel-demo
kubectl apply -f keptn/keptn-predeployment_shipping.yaml -n otel-demo


#Deploy the ingress rules
kubectl apply -f istio/istio_gateway.yaml
echo "--------------Demo--------------------"
echo "url of the demo: "
echo "Otel demo url: http://oteldemo.$IP.nip.io"
echo " Hipster-shop url : http://hipster-shop.$IP.nip.io"
echo " Litmus Chaos : http://litmus.$IP.nip.io"
echo "========================================================"


