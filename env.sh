CLUSTERS=()
for i in $(seq 1 ${1:-2}); do
    CLUSTERS+=("cluster${i}")
done

# export CTX_CLUSTER1=kind-cluster1
# export CTX_CLUSTER2=kind-cluster2

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN=test-token