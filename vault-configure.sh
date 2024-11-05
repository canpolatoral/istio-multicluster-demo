set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

createPkiRootCA() {
    vault secrets enable -path=pki_root pki

    vault write -field=certificate pki_root/root/generate/internal \
    common_name="mydomain.com" ttl=87600h > certs/CA_cert.crt

    vault write pki_root/config/urls \
        issuing_certificates="localhost:8200/v1/pki_root/ca" \
        crl_distribution_points="localhost:8200/v1/pki_root/crl"
}

createVaultPkiIntermediateCA() {

    local clustername=${1} # ex istio-cluster1

    vault secrets enable -path=pki_int_${clustername} pki
    vault secrets tune -max-lease-ttl=43800h pki_int_${clustername}

    vault write -format=json pki_int_${clustername}/intermediate/generate/internal \
            common_name="mydomain.com intermediate ${clustername}" \
            | jq -r '.data.csr' > certs/pki_intermediate_${clustername}.csr

    vault write -format=json pki_root/root/sign-intermediate csr=@certs/pki_intermediate_${clustername}.csr \
            format=pem ttl="43800h" \
            | jq -r '.data.certificate' > certs/intermediate_${clustername}.cert.pem

    cat certs/intermediate_${clustername}.cert.pem > certs/intermediate_${clustername}.chain.pem
    cat certs/CA_cert.crt >> certs/intermediate_${clustername}.chain.pem

    vault write pki_int_${clustername}/intermediate/set-signed certificate=@certs/intermediate_${clustername}.chain.pem

    vault write pki_int_${clustername}/roles/istio-ca-${clustername} \
        allowed_domains=istio-ca \
        allow_any_name=true  \
        enforce_hostnames=false \
        require_cn=false \
        allowed_uri_sans="spiffe://*" \
        max_ttl=72h
} 

setupVaultIntegration() {
  local context=${1}
  local clustername=${2}

  vault auth enable --path=${context} kubernetes  

  SA_JWT_TOKEN=$(kubectl --context=${context} get secret issuer-token-lmzpj -n cert-manager --output 'go-template={{ .data.token }}' | base64 --decode)
  KUBE_HOST=$(kubectl --context=${context} config view --minify | grep server | cut -f 2- -d ":" | tr -d " ") 
  KUBE_CA_CERT_DECODED=$(kubectl --context=${context} config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
  KUBE_CA_CERT=$(kubectl --context=${context} config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}')

  vault write auth/${context}/config \
  token_reviewer_jwt=${SA_JWT_TOKEN} \
  kubernetes_host=${KUBE_HOST} \
  kubernetes_ca_cert="${KUBE_CA_CERT_DECODED}" \
  issuer="https://kubernetes.default.svc.cluster.local" 

  vault policy write pki_int_${clustername} - <<EOF
path "pki_int_${clustername}*"    { capabilities = ["create", "read", "update", "delete", "list"] }
EOF

  vault write auth/${context}/role/issuer \
      bound_service_account_names=issuer \
      bound_service_account_namespaces=cert-manager \
      policies=pki_int_${clustername} \
      ttl=20m
}

createServiceAccountAndToken() {

  local context=${1} 

  # kubectl create namespace istio-system --context="${context}"

  kubectl apply --context=${context} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: issuer
  namespace: cert-manager
EOF

  kubectl apply --context=${context} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: issuer-token-lmzpj
  namespace: cert-manager
  annotations:
    kubernetes.io/service-account.name: issuer
type: kubernetes.io/service-account-token
EOF

  kubectl apply --context="${context}" -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: cert-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: issuer
    namespace: cert-manager
EOF

}

main () {

    createPkiRootCA
    createVaultPkiIntermediateCA istio-cluster1
    createVaultPkiIntermediateCA istio-cluster2

    createServiceAccountAndToken ${CTX_CLUSTER1}
    createServiceAccountAndToken ${CTX_CLUSTER2}

    setupVaultIntegration ${CTX_CLUSTER1} istio-cluster1
    setupVaultIntegration ${CTX_CLUSTER2} istio-cluster2
}

main