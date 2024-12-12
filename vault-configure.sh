set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh $1

createPkiRootCA() {

    mkdir -p certs

    vault secrets enable -path=pki_root pki

    vault write -field=certificate pki_root/root/generate/internal \
    common_name="mydomain.com" ttl=87600h > certs/CA_cert.crt

    vault write pki_root/config/urls \
        issuing_certificates="localhost:8200/v1/pki_root/ca" \
        crl_distribution_points="localhost:8200/v1/pki_root/crl"
}

createVaultPkiIntermediateCA() {

    local cluster=${1} # ex istio-cluster1

    vault secrets enable -path=pki_int_${cluster} pki
    vault secrets tune -max-lease-ttl=43800h pki_int_${cluster}

    vault write -format=json pki_int_${cluster}/intermediate/generate/internal \
            common_name="mydomain.com intermediate ${cluster}" \
            | jq -r '.data.csr' > certs/pki_intermediate_${cluster}.csr

    vault write -format=json pki_root/root/sign-intermediate csr=@certs/pki_intermediate_${cluster}.csr \
            format=pem ttl="43800h" \
            | jq -r '.data.certificate' > certs/intermediate_${cluster}.cert.pem

    cat certs/intermediate_${cluster}.cert.pem > certs/intermediate_${cluster}.chain.pem
    cat certs/CA_cert.crt >> certs/intermediate_${cluster}.chain.pem

    vault write pki_int_${cluster}/intermediate/set-signed certificate=@certs/intermediate_${cluster}.chain.pem

    vault write pki_int_${cluster}/roles/istio-ca-${cluster} \
        allowed_domains=istio-ca \
        allow_any_name=true  \
        enforce_hostnames=false \
        require_cn=false \
        allowed_uri_sans="spiffe://*" \
        max_ttl=72h
} 

setupVaultIntegration() {
  local cluster=${1}

  vault auth enable --path=${cluster} kubernetes  

  SA_JWT_TOKEN=$(kubectl --context=kind-${cluster} get secret issuer-token-lmzpj -n istio-system --output 'go-template={{ .data.token }}' | base64 --decode)
  KUBE_HOST=$(kubectl --context=kind-${cluster} config view --minify | grep server | cut -f 2- -d ":" | tr -d " ") 
  KUBE_CA_CERT_DECODED=$(kubectl --context=kind-${cluster} config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
  KUBE_CA_CERT=$(kubectl --context=kind-${cluster} config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}')

  vault write auth/${cluster}/config \
  token_reviewer_jwt=${SA_JWT_TOKEN} \
  kubernetes_host=${KUBE_HOST} \
  kubernetes_ca_cert="${KUBE_CA_CERT_DECODED}" \
  issuer="https://kubernetes.default.svc.cluster.local" 

  vault policy write pki_int_${cluster} - <<EOF
path "pki_int_${cluster}*"    { capabilities = ["create", "read", "update", "delete", "list"] }
EOF

  vault write auth/${cluster}/role/issuer \
      bound_service_account_names=issuer \
      bound_service_account_namespaces=istio-system \
      policies=pki_int_${cluster} \
      ttl=20m
}

createServiceAccountAndToken() {

  local cluster=${1} 

  # kubectl create namespace istio-system --context="${context}"

  kubectl apply --context=kind-${cluster} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: issuer
  namespace: istio-system
EOF

  kubectl apply --context=kind-${cluster} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: issuer-token-lmzpj
  namespace: istio-system
  annotations:
    kubernetes.io/service-account.name: issuer
type: kubernetes.io/service-account-token
EOF

  kubectl apply --context=kind-${cluster} -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: istio-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: issuer
    namespace: istio-system
EOF

}

main () {

    createPkiRootCA

    for cluster in ${CLUSTERS[@]}; do
        createVaultPkiIntermediateCA ${cluster}
        createServiceAccountAndToken ${cluster}
        setupVaultIntegration ${cluster}
    done
}

main