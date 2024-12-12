set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh $1

createClusters() {
    for cluster in ${CLUSTERS[@]}; do
        kind create cluster --name ${cluster}
    done

    for cluster in ${CLUSTERS[@]}; do
        kubectl --context kind-${cluster} label node ${cluster}-control-plane topology.kubernetes.io/zone=zone${cluster: -1}
    done
}

setupInitialNamespaces() {
    local context=${1}
    kubectl create namespace istio-system --context=kind-${context}
}

main() {

    createClusters

    for cluster in ${CLUSTERS[@]}; do
        setupInitialNamespaces ${cluster}
    done
}

main