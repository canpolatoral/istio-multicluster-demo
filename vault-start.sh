set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

vault server -dev -log-level=trace 
