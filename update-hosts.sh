set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh $1       

BASE_DOMAIN=${BASE_DOMAIN:-multicluster.com}

for cluster in "${CLUSTERS[@]}"; do
  ctx="kind-${cluster}"

  # 1. Wait until Istio ingress gets an External-IP
  kubectl --context "$ctx" -n istio-system \
          wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
          svc/istio-ingressgateway --timeout=180s

  ip=$(kubectl --context "$ctx" -n istio-system \
               get svc/istio-ingressgateway \
               -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  host="${cluster}.${BASE_DOMAIN}"

  # 2. Add or replace the line in /etc/hosts (needs root)
  if grep -qE "[[:space:]]${host}\$" /etc/hosts; then
    sudo sed -i.bak "s/^.*[[:space:]]${host}\$/${ip} ${host}/" /etc/hosts
  else
    echo "${ip} ${host}" | sudo tee -a /etc/hosts >/dev/null
  fi
  echo "✔  ${ip} → ${host}"
done