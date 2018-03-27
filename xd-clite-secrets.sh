source /kms_utils.sh

VAULT_HOSTS=$VAULT_HOST
VAULT_TOKEN=$1

if [ ! -n "$VAULT_TOKEN" ]; then
  echo "ERROR: You need to provide vault token"
  exit -1
fi

getCert "userland" "crossdata-1" "crossdata-1" "PEM" "./certs"
getCAbundle "./certs" PEM "ca-bundle.pem"
