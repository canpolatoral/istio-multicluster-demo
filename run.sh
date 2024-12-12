./cluster-delete-all.sh
./cluster-create.sh $1
./vault-configure.sh $1
./cert-manager-setup.sh $1
./istio-setup.sh $1
./argocd-setup.sh $1