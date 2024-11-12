set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

setupIstioCSR() {
  
    local context=${1}
    values_cluster="${context/kind/values}"

    helm upgrade cert-manager-istio-csr ./charts/cert-manager-istio-csr \
        --install \
        --namespace cert-manager \
        --wait \
        --values=./charts/cert-manager-istio-csr/"${values_cluster}".yaml \
        --kube-context=${context}
}

setupIstioBase() {

    local context=${1}

    values_cluster="${context/kind/values}"

    helm upgrade istio-base ./charts/istio/base \
        --install \
        --wait \
        --kube-context=${context} \
        --namespace istio-system \
        --values=./charts/istio/base/"${values_cluster}".yaml 

}

setupIstiod() {

    local context=${1}

    values_cluster="${context/kind/values}"

    helm upgrade istiod ./charts/istio/istiod \
        --install \
        --wait \
        --values=./charts/istio/istiod/"${values_cluster}".yaml \
        --namespace istio-system \
        --kube-context=${context} 
}

setupRemoteSecret() {

    local cluster1context=${1}
    local cluster2context=${2}

    local apiServerIP=$(kubectl --context=${cluster1context} get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.podIP}')

    local istioClusterName="${cluster1context/kind/istio}"

    istioctl create-remote-secret \
        --context=${cluster1context} \
        --server=https://${apiServerIP}:6443 \
        --name=${istioClusterName} | \
        kubectl apply -f - --context=${cluster2context}
}

setupIngressGateway() {
    local context=${1}

    values_cluster="${context/kind/values}"

    helm upgrade istio-ingressgateway ./charts/istio/ingress-gateway \
        --install \
        --wait \
        --values=./charts/istio/ingress-gateway/"${values_cluster}".yaml \
        --namespace istio-system \
        --kube-context=${context} 
}

setupEastWestGateway() {
    local context=${1}

    values_cluster="${context/kind/values}"

    helm upgrade istio-eastwestgateway ./charts/istio/eastwest-gateway \
        --install \
        --wait \
        --values=./charts/istio/eastwest-gateway/"${values_cluster}".yaml \
        --namespace istio-system \
        --kube-context=${context} 
}

setupPrometheus() {
    local context=${1}

    kubectl --context=${context} apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml
}

main() {
 
    setupIstioCSR ${CTX_CLUSTER1}
    setupIstioCSR ${CTX_CLUSTER2}
    
    setupIstioBase ${CTX_CLUSTER1}
    setupIstioBase ${CTX_CLUSTER2}

    setupIstiod ${CTX_CLUSTER1}
    setupIstiod ${CTX_CLUSTER2}

    setupRemoteSecret ${CTX_CLUSTER1} ${CTX_CLUSTER2}
    setupRemoteSecret ${CTX_CLUSTER2} ${CTX_CLUSTER1}

    setupIngressGateway ${CTX_CLUSTER1}
    setupIngressGateway ${CTX_CLUSTER2}

    setupEastWestGateway ${CTX_CLUSTER1}
    setupEastWestGateway ${CTX_CLUSTER2}

    setupPrometheus ${CTX_CLUSTER1}
    setupPrometheus ${CTX_CLUSTER2}
}

main