    helm upgrade --install account-service ./charts/banking/account \
      --wait \
      --kube-context="kind-cluster1" \
      --namespace=account \
      --create-namespace

    helm upgrade --install transfer-service ./charts/banking/transfer \
      --wait \
      --kube-context="kind-cluster1" \
      --namespace=transfer \
      --create-namespace