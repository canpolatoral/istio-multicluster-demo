set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

vault server -dev -dev-root-token-id=test-token -log-level=trace 
