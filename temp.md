# Start vault
vault server -dev -dev-root-token-id=test-token -log-level=trace 

# For external ip
sudo cloud-provider-kind

# setup 

export CTX_CLUSTER1=kind-cluster1
export CTX_CLUSTER2=kind-cluster2

istioctl --context $CTX_CLUSTER1 proxy-config endpoint transfer-service-c4df784c4-cf7tp.transfer | grep account
istioctl --context $CTX_CLUSTER2 proxy-config endpoint transfer-service-744d569498-ptqkb.transfer | grep account

kubectl --context $CTX_CLUSTER1 label node cluster1-control-plane topology.kubernetes.io/zone=myd
kubectl --context $CTX_CLUSTER2 label node cluster2-control-plane topology.kubernetes.io/zone=auh


kubectl --context="$CTX_CLUSTER1" apply -n account -f - <<EOF
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: account
spec:
  host: account-service.account.svc.cluster.local
  trafficPolicy:
    connectionPool:
      http:
        maxRequestsPerConnection: 1
    loadBalancer:
      simple: ROUND_ROBIN
      localityLbSetting:
        enabled: true
        failover:
          - from: myd
            to: auh
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
EOF

kubectl --context="$CTX_CLUSTER2" apply -n account -f - <<EOF
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: account
spec:
  host: account-service.account.svc.cluster.local
  trafficPolicy:
    connectionPool:
      http:
        maxRequestsPerConnection: 1
    loadBalancer:
      simple: ROUND_ROBIN
      localityLbSetting:
        enabled: true
        failover:
          - from: myd
            to: auh
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
EOF

kubectl --context="$CTX_CLUSTER1" apply -n transfer -f - <<EOF
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: transfer
spec:
  host: transfer-service.tranfer.svc.cluster.local
  trafficPolicy:
    connectionPool:
      http:
        maxRequestsPerConnection: 1
    loadBalancer:
      simple: ROUND_ROBIN
      localityLbSetting:
        enabled: true
        failover:
          - from: myd
            to: auh
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
EOF


kubectl --context="$CTX_CLUSTER1" delete DestinationRule account -n account
kubectl --context="$CTX_CLUSTER1" delete DestinationRule transfer -n account

kubectl --context="$CTX_CLUSTER1" delete DestinationRule transfer2 -n account



---------------------


kubectl --context="$CTX_CLUSTER1" apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: transfer-service
  namespace: transfer
spec:
  hosts:
    - "multicluster.mydemo.com" 
  gateways:
    - istio-system/ingress-gateway
  http:
    - match:
        - uri:
            prefix: "/transfer"
      rewrite:
        uri: /
      route:
        - destination:
            host: transfer-service.transfer.svc.cluster.local
            port:
              number: 80     
EOF

kubectl --context="$CTX_CLUSTER1" apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: account-service
  namespace: account
spec:
  hosts:
    - "multicluster.mydemo.com" 
  gateways:
    - istio-system/ingress-gateway
  http:
    - match:
        - uri:
            prefix: "/account"
      rewrite:
        uri: /
      route:
        - destination:
            host: account-service.account.svc.cluster.local
            port:
              number: 80     
EOF


kubectl --context="$CTX_CLUSTER1" apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ingress-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway 
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "multicluster.mydemo.com" 
EOF


--------------

kubectl --context="$CTX_CLUSTER1" get gateway ingress-gateway -n istio-system -o yaml
kubectl --context="$CTX_CLUSTER1" get virtualservice transfer-service -n transfer -o yaml

kubectl --context="$CTX_CLUSTER1" apply -f test/nginx-namespace.yaml
kubectl --context="$CTX_CLUSTER1" apply -f test/nginx-deployment.yaml
kubectl --context="$CTX_CLUSTER1" apply -f test/nginx-virtualservice.yaml

istioctl --context $CTX_CLUSTER1 proxy-config endpoint transfer-service-7987698867-t7k45.transfer | grep account

istioctl --context $CTX_CLUSTER1 proxy-config all transfer-service-575845f844-br7f7.transfer

istioctl --context $CTX_CLUSTER1 proxy-config endpoints transfer-service-6cf4f5b759-m4czj.transfer --cluster "outbound|80||account-service.account.svc.cluster.local"

kubectl --context $CTX_CLUSTER1 logs transfer-service-6cf4f5b759-m4czj -c istio-proxy -n transfer | grep "outlier"

kubectl --context $CTX_CLUSTER1 logs account-service-87fcb78d4-wfwlk -c istio-proxy -n account | grep "outlier"

kubectl --context $CTX_CLUSTER1 exec transfer-service-6cf4f5b759-m4czj -c istio-proxy -n transfer -- curl http://localhost:15000/stats | grep outlier



----------

# deploy kubevirt 

# Use kubectl to deploy the KubeVirt operator:

export VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)

echo $VERSION
kubectl create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml"

# Again use kubectl to deploy the KubeVirt custom resource definitions:

kubectl create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml"

# Check the deployment:

kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.phase}"