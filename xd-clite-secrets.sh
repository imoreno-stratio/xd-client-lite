source /kms_utils.sh

VAULT_HOSTS=$VAULT_HOST

login
getCert "userland" "crossdata-1" "crossdata-1" "PEM" "./certs"
getCAbundle "./certs" PEM "ca-bundle.pem"
