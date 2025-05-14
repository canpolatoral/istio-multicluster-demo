
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

  # 3. Wait until Argo CD server gets an External-IP
  kubectl --context "$ctx" -n argocd \
          wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
          svc/argocd-server --timeout=180s

  argo_ip=$(kubectl --context "$ctx" -n argocd \
                   get svc/argocd-server \
                   -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  argo_host="argo-${cluster}.${BASE_DOMAIN}"

  # 4. Add or replace the line in /etc/hosts (needs root)
  if grep -qE "[[:space:]]${argo_host}$" /etc/hosts; then
    sudo sed -i.bak "s/^.*[[:space:]]${argo_host}$/${argo_ip} ${argo_host}/" /etc/hosts
  else
    echo "${argo_ip} ${argo_host}" | sudo tee -a /etc/hosts >/dev/null
  fi
  echo "✔  ${argo_ip} → ${argo_host}"
done