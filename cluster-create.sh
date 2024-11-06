set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

createClusters() {
  kind create cluster --name cluster1
  kind create cluster --name cluster2
}

setupInitialNamespaces() {
    
    local context=${1}
    kubectl create namespace istio-system --context="${context}"
    # kubectl create namespace cert-manager --context="${context}"
}

main() {

  createClusters

  setupInitialNamespaces ${CTX_CLUSTER1}
  setupInitialNamespaces ${CTX_CLUSTER2}
}

main