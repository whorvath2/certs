#!/bin/zsh
# Creates a certificate, private key, and CA bundle suitable for use in TLS for the host name specified as the
# first argument, and stores the location of the corresponding files as podman secrets. The intermediate CA and
# related configuration should be specified in a .env file in this script's directory.

if [[ $# == 0 ]]
then
  echo "Usage: sh create_cert.sh <host name> [subjectAlternativeName1 subjectAlternativeName2 ...]"
  exit 0
fi
env_error=1
cert_error=2
podman_error=3

echo "Checking hostname..."
re='^[a-z0-9][a-z0-9-]*[a-z0-9]$'
if ! [[ $1 =~ $re ]]
then
  echo "Error: the host name $1 is malformed; it must match this expression: $re"
  exit $env_error
fi

HOST_NAME=$1
THIS_DIR="$(dirname "$(readlink -f "%N" ${0:A})")"
export THIS_DIR
echo "Checking environment..."
source "$THIS_DIR/check_path.sh"
check_path .env $env_error
if [[ $? != 0 ]]
then
  echo "Unable to find .env file!"
  exit $env_error
fi
source "$THIS_DIR/.env"

if [[ -a ${THIS_DIR}/.dev_env ]]
then
  source "$THIS_DIR/.dev_env"
fi


TLS_DIR
COUNTRY
STATE
LOCALE
ORGANIZATION
ORGANIZATIONAL_UNIT
CERTS_DIR
REVOKED_CERTS_DIR
PRIVATE_KEY_DIR
OPENSSL_CONF_PATH
OPENSSL_EXT_PATH
OPENSSL_PASSIN_PATH
ROOT_CA_PATH
INTERMEDIATE_CA_KEY_PATH
INTERMEDIATE_CA_BUNDLE_PATH

if ! [[ \
-n $TLS_DIR \
&& -n $COUNTRY \
&& -n $STATE \
&& -n $LOCALE \
&& -n $ORGANIZATION \
&& -n $ORGANIZATIONAL_UNIT \
&& -n $CERTS_DIR \
&& -n $REVOKED_CERTS_DIR
&& -n $PRIVATE_KEY_DIR \
&& -n $OPENSSL_CONF_PATH \
&& -n $OPENSSL_EXT_PATH \
&& -n $OPENSSL_PASSIN_PATH \
&& -n $INTERMEDIATE_CA_KEY_PATH \
&& -n $INTERMEDIATE_CA_BUNDLE_PATH \
&& -n $ROOT_CA_PATH \
]] ;
then
  echo "All needed environment variables aren't specified:
  TLS_DIR: $TLS_DIR
  COUNTRY: $COUNTRY
  STATE: $STATE
  LOCALE: $LOCALE
  ORGANIZATION: $ORGANIZATION
  ORGANIZATIONAL_UNIT: $ORGANIZATIONAL_UNIT
  CERTS_DIR: $CERTS_DIR
  REVOKED_CERTS_DIR: $REVOKED_CERTS_DIR
  PRIVATE_KEY_DIR: $PRIVATE_KEY_DIR
  OPENSSL_CONF_PATH: $OPENSSL_CONF_PATH
  OPENSSL_EXT_PATH: $OPENSSL_EXT_PATH
  OPENSSL_PASSIN_PATH: $OPENSSL_PASSIN_PATH
  INTERMEDIATE_CA_KEY_PATH: $INTERMEDIATE_CA_KEY_PATH
  INTERMEDIATE_CA_BUNDLE_PATH: $INTERMEDIATE_CA_BUNDLE_PATH
  ROOT_CA_PATH: $ROOT_CA_PATH"
  exit $env_error
fi

echo "Checking paths..."
check_path "$TLS_DIR" $env_error
check_path "$CERTS_DIR" $env_error
check_path "$PRIVATE_KEY_DIR" $env_error
check_path "$INTERMEDIATE_CA_KEY_PATH" $env_error
check_path "$INTERMEDIATE_CA_BUNDLE_PATH" $env_error
check_path "$OPENSSL_CONF_PATH" $env_error
check_path "$OPENSSL_EXT_PATH" $env_error
check_path "$OPENSSL_PASSIN_PATH" $env_error
check_path "$ROOT_CA_PATH" $env_error

echo "Verifying intermediate CA..."
if ! openssl verify -CAfile "$ROOT_CA_PATH" "$INTERMEDIATE_CA_BUNDLE_PATH" ;
then
  echo "Unable to verify intermediate CA against root CA!"
  exit $cert_error
fi

HOST_KEY_PATH="$PRIVATE_KEY_DIR/$HOST_NAME-key.pem"
HOST_CSR_PATH="$CERTS_DIR/$HOST_NAME.csr"
HOST_CERT_PATH="$CERTS_DIR/$HOST_NAME.crt"
HOST_CA_BUNDLE_PATH="$CERTS_DIR/$HOST_NAME-ca-bundle.pem"
TEMP_EXT_PATH="$THIS_DIR/temp_server_ext.cnf"

remove_path () {
  if [[ -a "$1" ]]
  then
    rm "$1"
  fi
}

echo "Checking for existing certificate at $HOST_CERT_PATH..."
overwrite="false"
if [[ -a "$HOST_CERT_PATH" ]]
then
  vared -p 'Found existing certificate file - Revoke and replace? ' -c tmp
  re='^[yY][eE]?[sS]?$'
  if [[ $tmp =~ $re ]]
  then
    overwrite="true"
  fi
fi

if [[ $overwrite == "true" || ! -a "$HOST_CERT_PATH" ]]
then
  echo "Creating new host certificate for $HOST_NAME..."
  if [[ -a "$HOST_KEY_PATH" && $overwrite == "true" ]]
  then
    echo "Revoking existing $HOST_NAME certificate..."
    if openssl ca \
      -config $OPENSSL_CONF_PATH \
      -revoke $HOST_CERT_PATH \
      -passin "file:$OPENSSL_PASSIN_PATH" ;
    then
      echo "Certificate successfully revoked! Archiving..."
      if ! mv "$HOST_KEY_PATH" "$REVOKED_CERTS_DIR/${HOST_KEY_PATH:t}.$(date +%s)" ;
      then
        echo "Error: unable to archive revoked certificate at $HOST_KEY_PATH"
        exit $cert_error
      fi
    else
      echo "Error: unable to revoke existing certificate"
      exit $cert_error
    fi
  fi
  echo "Generating new key for $HOST_NAME..."
  if ! openssl genrsa -out "$HOST_KEY_PATH" 4096 ;
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
  CERT_SUBJ="/C=$COUNTRY/ST=$STATE/L=$LOCALE/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$HOST_NAME"
  if [[ $# -gt 1 ]] ;
  then
    sans="\n"
    i=0
    argv[-1]=()
    while [[ -n ${argv[-1]} ]]
    do {
      sans+="DNS.$i = ${argv[-1]}\n"
      argv[-1]=()
      i=$((i + 1))
    }
    done
    cp "$OPENSSL_EXT_PATH" "$TEMP_EXT_PATH"
    echo "$sans"
    echo "$sans" >> "$TEMP_EXT_PATH"
    unset OPENSSL_EXT_PATH && OPENSSL_EXT_PATH="$TEMP_EXT_PATH"
  fi

  if ! openssl req \
    -new \
    -key "$HOST_KEY_PATH" \
    -out "$HOST_CSR_PATH" \
    -subj "$CERT_SUBJ" \
    -passin "file:$OPENSSL_PASSIN_PATH" ;
  then
    echo "Error creating certificate signing request!"
    if [[ -a "$HOST_CSR_PATH" ]]
    then
      remove_path "$HOST_CSR_PATH"d
    fi
    exit $cert_error
  fi

  if ! openssl ca \
  -batch \
  -notext \
  -cert "$INTERMEDIATE_CA_BUNDLE_PATH" \
  -config "$OPENSSL_CONF_PATH" \
  -extfile "$OPENSSL_EXT_PATH" \
  -in "$HOST_CSR_PATH" \
  -out "$HOST_CERT_PATH" \
  -days 3650 \
  -passin "file:$OPENSSL_PASSIN_PATH" \
  -keyfile "$INTERMEDIATE_CA_KEY_PATH" ;
  then
    echo "Error creating server certificate!"
    exit $cert_error
  fi
  cat "$HOST_CERT_PATH" "$INTERMEDIATE_CA_BUNDLE_PATH" > "$HOST_CA_BUNDLE_PATH"
  if ! openssl x509 -in "$HOST_CA_BUNDLE_PATH" -out "$HOST_CA_BUNDLE_PATH" -outform PEM ;
  then
    echo "Error converting server certificate to PEM!"
    exit $cert_error
  fi
  if [[ -a "$TEMP_EXT_PATH" ]]
  then
    rm "$TEMP_EXT_PATH"
  fi
  else
    echo "Using existing certificate..."
fi

if ! [[ -a "$HOST_KEY_PATH" ]]
then
  echo "Error: $HOST_NAME certificate key at $HOST_KEY_PATH is missing"
  exit $env_error
fi
echo "Verifying certificate chain..."
if ! openssl verify -CAfile "$INTERMEDIATE_CA_BUNDLE_PATH" "$HOST_CA_BUNDLE_PATH";
then
  echo "Error: Unable to verify $HOST_CA_BUNDLE_PATH against $INTERMEDIATE_CA_BUNDLE_PATH"
  exit $cert_error
else
  echo "  ...Verified $HOST_CA_BUNDLE_PATH against $INTERMEDIATE_CA_BUNDLE_PATH"
fi

echo "Removing podman secrets..."
source "$THIS_DIR/remove_podman_secret.sh"
remove_secret "${HOST_NAME}_cert_key" $podman_error
remove_secret "${HOST_NAME}_cert_pub" $podman_error
remove_secret "${HOST_NAME}_cert_bundle_pub" $podman_error

echo "Creating podman secrets..."
source "$THIS_DIR/create_podman_secret.sh"
create_secret "${HOST_NAME}_cert_key" "$HOST_KEY_PATH" $podman_error
create_secret "${HOST_NAME}_cert_pub" "$HOST_CERT_PATH" $podman_error
create_secret "${HOST_NAME}_cert_bundle_pub" "$HOST_CA_BUNDLE_PATH" $podman_error

echo "Created podman secrets: ${HOST_NAME}_cert_key, ${HOST_NAME}_cert_pub, ${HOST_NAME}_ca_bundle_pub"

export HOST_KEY_PATH
export HOST_CERT_PATH
export HOST_CA_BUNDLE_PATH
echo "Exported HOST_KEY_PATH, HOST_CERT_PATH, HOST_CA_BUNDLE_PATH"
