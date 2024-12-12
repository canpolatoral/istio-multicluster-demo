set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh $1

setupCertManager() {
    
    local cluster=${1} 
    
    helm upgrade \
      cert-manager ./charts/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version v1.16.1 \
      --values=./charts/cert-manager/"values-${cluster}".yaml \
      --install \
      --wait \
      --kube-context=kind-${cluster}
}

createIssuer() {

  local cluster=${1} 

  kubectl apply --context=kind-${cluster} -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: istio-ca
  namespace: istio-system
spec:
  vault:
    server: http://host.docker.internal:8200
    path: pki_int_${cluster}/sign/istio-ca-${cluster}
    auth:
      kubernetes:
        mountPath: /v1/auth/${cluster} 
        role: issuer
        secretRef:
          name: issuer-token-lmzpj
          key: token
EOF
}

main () {

    helm repo add jetstack https://charts.jetstack.io

    for cluster in ${CLUSTERS[@]}; do
        setupCertManager ${cluster}
        createIssuer ${cluster}
    done
}

main