set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

setupArgoCD() {
  
    local context=${1}

    kubectl create namespace argocd --context=${context}

    helm upgrade --install argocd ./charts/argocd \
      --wait \
      --kube-context="${context}" \
      --namespace=argocd
}

installArgoCDApps() {
  
    local context=${1}

    values_cluster="${context/kind/values}"

    helm upgrade --install argocd-apps ./charts/argocd-apps \
    --wait \
    --kube-context="${context}" \
    --values=./charts/argocd-apps/values-base.yaml \
    --values=./charts/argocd-apps/"${values_cluster}".yaml \
    --namespace=argocd
}

# setupRemoteSecret() {

#     local cluster1context=${1}
#     local cluster2context=${2}

#     local apiServerIP=$(kubectl --context=${cluster1context} get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.podIP}')

#     local istioClusterName="${cluster1context/kind/istio}"

#     istioctl create-remote-secret \
#         --context=${cluster1context} \
#         --server=https://${apiServerIP}:6443 \
#         --name=${istioClusterName} | \
#         kubectl apply -f - --context=${cluster2context}
# }

main() {

    # setupRemoteSecret ${CTX_CLUSTER1} ${CTX_CLUSTER2}
    # setupRemoteSecret ${CTX_CLUSTER2} ${CTX_CLUSTER1}

    setupArgoCD ${CTX_CLUSTER1}
    setupArgoCD ${CTX_CLUSTER2}

    installArgoCDApps ${CTX_CLUSTER1}
    installArgoCDApps ${CTX_CLUSTER2}
}

main