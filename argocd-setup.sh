set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh $1

setupArgoCD() {
  
    local cluster=${1}

    kubectl create namespace argocd --context=kind-${cluster}

    helm upgrade --install argocd ./charts/argocd \
      --wait \
      --kube-context=kind-${cluster} \
      --namespace=argocd
}

installArgoCDApps() {
  
    local cluster=${1}

    helm upgrade --install argocd-apps ./charts/argocd-apps \
    --wait \
    --kube-context=kind-${cluster} \
    --values=./charts/argocd-apps/values-base.yaml \
    --values=./charts/argocd-apps/values-"${cluster}".yaml \
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

    for cluster in ${CLUSTERS[@]}; do
        setupArgoCD ${cluster}
        installArgoCDApps ${cluster}
    done
}

main