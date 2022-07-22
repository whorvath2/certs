#!/bin/zsh
if [[ $# == 0 ]]
then
  echo "Usage: sh build.sh <host name>"
  exit 0
fi
env_error=1
cert_error=2
podman_error=3

re='^[a-z0-9][a-z0-9-]*[a-z0-9]$'
if ! [[ $1 =~ $re ]]
then
  echo "error: Host name is malformed"
  exit $env_error
fi

HOST_NAME=$1

source check_path.sh
check_path .env $env_error
source .env

if [[ -a .dev_env ]]
then
  source .dev_env
fi

if ! { [[ -n $TLS_DIR ]] \
&& [[ -n $COUNTRY ]] \
&& [[ -n $STATE ]] \
&& [[ -n $LOCALE ]] \
&& [[ -n $ORGANIZATION ]] \
&& [[ -n $CERTS_DIR ]] \
&& [[ -n $PRIVATE_KEY_DIR ]] \
&& [[ -n $CA_KEY_PATH ]] \
&& [[ -n $CA_BUNDLE_PATH ]] \
&& [[ -n $OPENSSL_CONF_PATH ]] \
&& [[ -n $OPENSSL_EXT_PATH ]] \
&& [[ -n $OPENSSL_PASSIN_PATH ]] ; }
then
  echo "All needed environment variables aren't specified: \
  TLS_DIR: $TLS_DIR \
  COUNTRY: $COUNTRY \
  STATE: $STATE \
  LOCALE: $LOCALE \
  ORGANIZATION: $ORGANIZATION \
  CERTS_DIR: $CERTS_DIR \
  PRIVATE_KEY_DIR: $PRIVATE_KEY_DIR \
  CA_KEY_PATH: $CA_KEY_PATH \
  CA_BUNDLE_PATH: $CA_BUNDLE_PATH \
  OPENSSL_CONF_PATH: $OPENSSL_CONF_PATH \
  OPENSSL_EXT_PATH: $OPENSSL_EXT_PATH \
  OPENSSL_PASSIN_PATH: $OPENSSL_PASSIN_PATH"
  exit $env_error
fi

check_path "$TLS_DIR" $env_error
check_path "$CERTS_DIR" $env_error
check_path "$PRIVATE_KEY_DIR" $env_error
check_path "$CA_KEY_PATH" $env_error
check_path "$CA_BUNDLE_PATH" $env_error
check_path "$OPENSSL_CONF_PATH" $env_error
check_path "$OPENSSL_EXT_PATH" $env_error
check_path "$OPENSSL_PASSIN_PATH" $env_error

HOST_KEY_PATH="$PRIVATE_KEY_DIR/$HOST_NAME-key.pem"
HOST_CSR_PATH="$CERTS_DIR/$HOST_NAME.csr"
HOST_CERT_PATH="$CERTS_DIR/$HOST_NAME-chain-bundle.cert.pem"

remove_path () {
  if [[ -a "$1" ]]
  then
    rm "$1"
  fi
}

remove_paths () {
  remove_path "$HOST_KEY_PATH"
  remove_path "$HOST_CSR_PATH"
  remove_path "$HOST_CERT_PATH"
}

if ! [[ -a "$HOST_CERT_PATH" ]]
then
  echo "Creating new host certificate for $HOST_NAME..."
  if [[ -a "$HOST_KEY_PATH" ]]
  then
    echo "Removing existing $HOST_NAME key..."
    remove_path "$HOST_KEY_PATH"
  fi
  echo "Generating new key for $HOST_NAME..."
  openssl genrsa -out "$HOST_KEY_PATH" 4096
  if [[ $(echo $?) -ne 0 ]]
  then
    echo "Error generating $HOST_NAME key!"
    exit $cert_error
  else
    echo "Generated key at $HOST_KEY_PATH"
  fi

  if [[ -a "$HOST_CSR_PATH" ]]
  then
    echo "Removing existing certificate signing request..."
    remove_path "$HOST_CSR_PATH"
  fi

  echo "Creating certificate signing request..."
  CERT_SUBJ="/C=$COUNTRY/ST=$STATE/L=$LOCALE/O=$ORGANIZATION/CN=$HOST_NAME"
  openssl req \
  -new \
  -key "$HOST_KEY_PATH" \
  -out "$HOST_CSR_PATH" \
  -subj "$CERT_SUBJ" \
  -passin "file:$OPENSSL_PASSIN_PATH"

  if [[ $? != 0 ]]
  then
    echo "Error creating certificate signing request!"
    if [[ -a "$HOST_CSR_PATH" ]]
    then
      remove_path "$HOST_CSR_PATH"
    fi
    exit $cert_error
  fi

  openssl ca \
  -batch \
  -cert "$CA_BUNDLE_PATH" \
  -config "$OPENSSL_CONF_PATH" \
  -extfile "$OPENSSL_EXT_PATH" \
  -in "$HOST_CSR_PATH" \
  -out "$HOST_CERT_PATH" \
  -days 365 \
  -passin "file:$OPENSSL_PASSIN_PATH" \
  -keyfile "$CA_KEY_PATH"
  if [[ $(echo $?) -ne 0 ]]
  then
    echo "Error creating server certificate!"
    remove_paths
    exit $cert_error
  fi

  openssl x509 -in "$HOST_CERT_PATH" -out "$HOST_CERT_PATH" -outform PEM
  if [[ $(echo $?) -ne 0 ]]
  then
    echo "Error converting server certificate to PEM!"
    remove_paths
    exit $cert_error
  fi
fi

if ! [[ -a "$HOST_KEY_PATH" ]]
then
  echo "$HOST_NAME certificate key at $HOST_KEY_PATH is missing!"
  exit $env_error
fi

echo "Removing podman secrets..."
source remove_podman_secret.sh

remove_secret "${HOST_NAME}_cert_key" $podman_error
remove_secret "${HOST_NAME}_cert_pub" $podman_error
remove_secret "${HOST_NAME}_cert_bundle_pub" $podman_error

echo "Creating podman secrets..."
source create_podman_secret.sh

create_secret "${HOST_NAME}_cert_key" "$HOST_KEY_PATH" $podman_error
create_secret "${HOST_NAME}_cert_pub" "$HOST_CERT_PATH" $podman_error
create_secret "${HOST_NAME}_cert_bundle_pub" "$CA_BUNDLE_PATH" $podman_error
echo "Created podman secrets: ${HOST_NAME}_cert_key, ${HOST_NAME}_cert_pub, ${HOST_NAME}_cert_bundle_pub"