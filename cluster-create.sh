set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

createClusters() {
  kind create cluster --name cluster1
  kind create cluster --name cluster2
}

main() {

  createClusters
}

main