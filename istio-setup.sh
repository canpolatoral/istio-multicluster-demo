set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh $1

setupIstioCSR() {
    local cluster=${1}

    helm upgrade cert-manager-istio-csr ./charts/cert-manager-istio-csr \
        --install \
        --namespace cert-manager \
        --wait \
        --values=./charts/cert-manager-istio-csr/values-"${cluster}".yaml \
        --kube-context=kind-${cluster}
}

setupIstioBase() {
    local cluster=${1}

    helm upgrade istio-base ./charts/istio/base \
        --install \
        --wait \
        --kube-context=kind-${cluster} \
        --namespace istio-system \
        --values=./charts/istio/base/values-"${cluster}".yaml 
}

setupIstiod() {
    local cluster=${1}

    helm upgrade istiod ./charts/istio/istiod \
        --install \
        --wait \
        --values=./charts/istio/istiod/values-"${cluster}".yaml \
        --namespace istio-system \
        --kube-context=kind-${cluster} 
}

setupRemoteSecret() {
    local cluster1context=${1}
    local cluster2context=${2}

    local apiServerIP=$(kubectl --context=kind-${cluster1context} get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.podIP}')

    local istioClusterName="${cluster1context/kind/istio}"

    istioctl create-remote-secret \
        --context=kind-${cluster1context} \
        --server=https://${apiServerIP}:6443 \
        --name=${istioClusterName} | \
        kubectl apply -f - --context=kind-${cluster2context}
}

setupIngressGateway() {
    local cluster=${1}

    # namespace is changed from istio-system to istio-ingress

    helm upgrade istio-ingressgateway ./charts/istio/ingress-gateway \
        --install \
        --wait \
        --values=./charts/istio/ingress-gateway/values-"${cluster}".yaml \
        --namespace istio-ingress \
        --kube-context=kind-${cluster} 
}

setupEastWestGateway() {
    local cluster=${1}

    # namespace is changed from istio-system to istio-ingress

    helm upgrade istio-eastwestgateway ./charts/istio/eastwest-gateway \
        --install \
        --wait \
        --values=./charts/istio/eastwest-gateway/values-"${cluster}".yaml \
        --namespace istio-ingress \
        --kube-context=kind-${cluster} 
}

setupPrometheus() {
    local cluster=${1}
    kubectl --context=kind-${cluster} apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml
}

main() {

    for cluster in ${CLUSTERS[@]}; do
        setupIstioCSR ${cluster}
        setupIstioBase ${cluster}
        setupIstiod ${cluster}
        setupIngressGateway ${cluster}

        # if cluster count is 1 then skip creating east west gateway
        if [ ${#CLUSTERS[@]} -gt 1 ]; then
            setupEastWestGateway ${cluster}
        fi
        # setupPrometheus ${cluster}
    done

    # if cluster count is 1 then skip creating remote secrets
    if [ ${#CLUSTERS[@]} -gt 1 ]; then
        for i in ${!CLUSTERS[@]}; do
            for j in ${!CLUSTERS[@]}; do
                if [ $i -ne $j ]; then
                    setupRemoteSecret ${CLUSTERS[$i]} ${CLUSTERS[$j]}
                fi
            done
        done
    fi
}

main