set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

setupCertManager() {
    
    local context=${1} 
    values_cluster="${context/kind/values}"
    
    helm upgrade \
      cert-manager ./charts/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version v1.16.1 \
      --values=./charts/cert-manager/"${values_cluster}".yaml \
      --install \
      --wait \
      --kube-context=${context}
}

createIssuer() {

  local context=${1} 
  local clustername=${2}

  kubectl apply --context="${context}" -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: istio-ca
  namespace: istio-system
spec:
  vault:
    server: http://host.docker.internal:8200
    path: pki_int_${clustername}/sign/istio-ca-${clustername}
    auth:
      kubernetes:
        mountPath: /v1/auth/${context} 
        role: issuer
        secretRef:
          name: issuer-token-lmzpj
          key: token
EOF
}

main () {

    helm repo add jetstack https://charts.jetstack.io

    setupCertManager ${CTX_CLUSTER1}
    setupCertManager ${CTX_CLUSTER2}

    createIssuer ${CTX_CLUSTER1} istio-cluster1
    createIssuer ${CTX_CLUSTER2} istio-cluster2
}

main