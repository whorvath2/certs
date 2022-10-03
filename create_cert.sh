#!/bin/zsh
# Creates a certificate, private key, and CA bundle suitable for use in TLS for the host name specified as the
# first argument, and stores the location of the corresponding files as podman secrets. The intermediate CA and
# related configuration should be specified in a .env file in this script's directory.
env_error=1
cert_error=2
podman_error=3

if [[ $# == 0 ]]
then
  echo "Usage: sh create_cert.sh <host name> [subjectAlternativeName1 subjectAlternativeName2 ...]"
  exit $env_error
fi

echo "Creating certificate...Checking hostnames $*..."
re='^([a-z0-9][a-z0-9-]*[a-z0-9] ?)$'
for item in ${argv[1,$#]}
do
  if ! [[ $item =~ $re ]]
  then
    echo "Error: the host name $item is malformed; each must match this expression: ([a-z0-9][a-z0-9-]*[a-z0-9])" &>/dev/null
    exit $env_error
  fi
done

HOST_NAME=$1
THIS_DIR="$(dirname "$(readlink -f "%N" ${0:A})")"
export THIS_DIR

echo "Checking environment..."
source "$THIS_DIR/check_path.sh"
if ! check_path .env
then
  echo "Error: .env not found"
  exit $env_error
fi

if [[ $? != 0 ]]
then
  echo "Error: Unable to find .env file" &>/dev/null
  exit $env_error
fi
source "$THIS_DIR/.env"
if [[ -a ${THIS_DIR}/.dev_env ]]
then
  source "$THIS_DIR/.dev_env"
fi
if ! . "$THIS_DIR/check_env.sh" ;
then
  echo "Failed environment check."
  exit $env_error
fi

echo "Checking paths..."
if ! check_path "$CERTS_DIR" \
"$PRIVATE_KEY_DIR" \
"$INTERMEDIATE_CA_KEY_PATH" \
"$INTERMEDIATE_CA_BUNDLE_PATH" \
"$OPENSSL_CONF_PATH" \
"$OPENSSL_EXT_PATH" \
"$OPENSSL_PASSIN_PATH" \
"$ROOT_CA_PATH" ;
then
  echo "Error: Unable to find all needed certificate-related paths"
  exit $env_error
fi

echo "Verifying intermediate CA..."
if ! openssl verify -CAfile "$ROOT_CA_PATH" "$INTERMEDIATE_CA_BUNDLE_PATH" ;
then
  echo "Error: Unable to verify intermediate CA against root CA" &>/dev/null
  exit $cert_error
fi

HOST_KEY_PATH="$PRIVATE_KEY_DIR/$HOST_NAME-key.pem"
HOST_CSR_PATH="$CERTS_DIR/$HOST_NAME.csr"
HOST_CERT_PATH="$CERTS_DIR/$HOST_NAME.crt"
HOST_CERT_BUNDLE_PATH="$CERTS_DIR/$HOST_NAME-ca-bundle.pem"
TEMP_EXT_PATH="$THIS_DIR/temp_server_ext.cnf"
echo "
  HOST_KEY_PATH=$HOST_KEY_PATH
  HOST_CSR_PATH=$HOST_CSR_PATH
  HOST_CERT_PATH=$HOST_CERT_PATH
  HOST_CERT_BUNDLE_PATH=$HOST_CERT_BUNDLE_PATH
  TEMP_EXT_PATH=$TEMP_EXT_PATH
"
remove_path () {
  if [[ -a "$1" ]]
  then
    rm "$1"
  fi
}

echo "Checking for existing certificate at $HOST_CERT_PATH..."
re='^[yY][eE]?[sS]?$'
overwrite="false"
if [[ -a "$HOST_CERT_PATH" ]]
then
  vared -p 'Found existing certificate file - Revoke and replace? ' -c revoke
  if [[ $revoke =~ $re ]]
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
      -config "$OPENSSL_CONF_PATH" \
      -revoke "$HOST_CERT_PATH" \
      -passin "file:$OPENSSL_PASSIN_PATH" ;
    then
      echo "Certificate successfully revoked! Archiving..."
      if ! mv "$HOST_KEY_PATH" "$REVOKED_CERTS_DIR/${HOST_KEY_PATH:t}.$(date +%s)" ;
      then
        echo "Error: unable to move revoked certificate at $HOST_KEY_PATH" &>/dev/null
        exit $cert_error
      fi
    else
      echo "Error: unable to revoke existing certificate" &>/dev/null
      vared -p 'Ignore and continue? ' -c keep_going
      re='^[yY][eE]?[sS]?$'
      if [[ $keep_going =~ $re ]]
      then
        echo "...Continuing creation new certificate"
      else
        exit $cert_error
      fi
    fi
  fi
  echo "Generating new key for $HOST_NAME..."
  if ! openssl genrsa -out "$HOST_KEY_PATH" 4096 ;
  then
    echo "Error: $HOST_NAME key generation failed" &>/dev/null
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
  echo "  CSR subject: $CERT_SUBJ
  Adding alternative names..."
  if [[ $# -gt 1 ]] ;
  then
    sans="\n"
    i=0
    for item in ${argv[2,$#]}
    do
      sans+="DNS.$i = ${item}\n"
      i=$((i + 1))
    done
    cp "$OPENSSL_EXT_PATH" "$TEMP_EXT_PATH"
    echo "$sans" >> "$TEMP_EXT_PATH"
    unset OPENSSL_EXT_PATH && OPENSSL_EXT_PATH="$TEMP_EXT_PATH"
  fi

  echo "  Generating CSR..."
  if ! openssl req \
    -new \
    -verify \
    -key "$HOST_KEY_PATH" \
    -out "$HOST_CSR_PATH" \
    -subj "$CERT_SUBJ" ;
  then
    echo "Error: creating certificate signing request failed" &>/dev/null
    if [[ -a "$HOST_CSR_PATH" ]]
    then
      remove_path "$HOST_CSR_PATH"d
    fi
    exit $cert_error
  fi
  if ! check_path "$HOST_CSR_PATH"
  then
    echo "Error: file at $HOST_CSR_PATH is missing"
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
  -keyfile "$INTERMEDIATE_CA_KEY_PATH" \
  -passin "file:$OPENSSL_PASSIN_PATH" ;
  then
    echo "Error: creating server certificate failed" &>/dev/null
    exit $cert_error
  fi
  cat "$HOST_CERT_PATH" "$INTERMEDIATE_CA_BUNDLE_PATH" > "$HOST_CERT_BUNDLE_PATH"
  if [[ -a "$TEMP_EXT_PATH" ]]
  then
    rm "$TEMP_EXT_PATH"
  fi
  else
    echo "Using existing certificate..."
fi

if ! [[ -a "$HOST_KEY_PATH" ]]
then
  echo "Error: $HOST_NAME certificate key at $HOST_KEY_PATH is missing" &>/dev/null
  exit $env_error
fi
echo "Verifying certificate chain..."
if ! openssl verify -CAfile "$INTERMEDIATE_CA_BUNDLE_PATH" "$HOST_CERT_BUNDLE_PATH";
then
  echo "Error: Unable to verify $HOST_CERT_BUNDLE_PATH against $INTERMEDIATE_CA_BUNDLE_PATH" &>/dev/null
  exit $cert_error
else
  echo "  ...Verified $HOST_CERT_BUNDLE_PATH against $INTERMEDIATE_CA_BUNDLE_PATH"
fi

set_openssl_server_pid () {
  server_line=$(ps -a | grep "[o]penssl s_server")
  if [[ -n "$server_line" ]]
  then
    server_pid=$(echo $server_line | awk "{ print \$1 }")
  else
    server_pid=0
  fi
  echo "server_pid=$server_pid"
}

kill_openssl_server () {
  echo "Killing openssl s_server if it is running..."
  set_openssl_server_pid
  if [[ $server_pid -gt 0 ]]
  then
    kill $server_pid
  fi
}

echo "Checking certificate using openssl client and server..."
kill_openssl_server
echo "Starting openssl s_server...
  HOST_KEY_PATH: $HOST_KEY_PATH
  HOST_CERT_BUNDLE_PATH: $HOST_CERT_BUNDLE_PATH
"
openssl s_server \
  -key "$HOST_KEY_PATH" \
  -cert "$HOST_CERT_BUNDLE_PATH" \
  -accept 44330 \
  -www &
sleep 3
set_openssl_server_pid
if [[ $server_pid -eq 0  ]]
then
  echo "Error: openssl_server failed to start"
  exit $env_error
fi
echo "  ...server started..."

echo "Q" > q.txt
echo "Checking connection with CAfile $INTERMEDIATE_CA_BUNDLE_PATH..."
if ! openssl s_client -CAfile "$INTERMEDIATE_CA_BUNDLE_PATH" -connect localhost:44330 < q.txt ;
then
  echo "Error: certificate is invalid"
  kill_openssl_server
  rm q.txt
  exit $env_error
else
  echo "Success: connected to openssl server"
  rm q.txt
  kill_openssl_server
fi

echo "Checking podman VM..."
if ! source "$THIS_DIR/podman_vm.sh" && start_vm ;
then
  echo "Error: podman vm not running" &>/dev/null
  exit $podman_error
fi

echo "Removing podman secrets..."
# If the secrets don't exist, we don't care, so we'll swallow the error messages
podman secret rm "${HOST_NAME}_cert_key" &>/dev/null
podman secret rm "${HOST_NAME}_cert_pub" &>/dev/null
podman secret rm "${HOST_NAME}_cert_bundle_pub" &>/dev/null
podman secret rm "intermediate_ca_bundle_pub" &>/dev/null
podman secret rm "root_ca_pub" &>/dev/null

echo "Creating podman secrets..."
if ! podman secret create "${HOST_NAME}_cert_key" "$HOST_KEY_PATH"
then
  echo "Error: unable to create podman secret $HOST_KEY_PATH"
  exit $podman_error
fi
if ! podman secret create "${HOST_NAME}_cert_pub" "$HOST_CERT_PATH"
then
  echo "Error: unable to create podman secret $HOST_CERT_PATH"
  exit $podman_error
fi
if ! podman secret create "${HOST_NAME}_cert_bundle_pub" "$HOST_CERT_BUNDLE_PATH"
then
  echo "Error: unable to create podman secret $HOST_CERT_BUNDLE_PATH"
  exit $podman_error
fi
if ! podman secret create "intermediate_ca_bundle_pub" "$INTERMEDIATE_CA_BUNDLE_PATH"
then
  echo "Error: unable to create podman secret $INTERMEDIATE_CA_BUNDLE_PATH"
  exit $podman_error
fi
if ! podman secret create "root_ca_pub" "$ROOT_CA_PATH"
then
  echo "Error: unable to create podman secret $ROOT_CA_PATH"
  exit $podman_error
fi

echo "Created podman secrets:
  ${HOST_NAME}_cert_key
  ${HOST_NAME}_cert_pub
  ${HOST_NAME}_cert_bundle_pub
  intermediate_ca_bundle_pub
  root_ca_pub
"

export HOST_KEY_PATH
export HOST_CERT_PATH
export HOST_CERT_BUNDLE_PATH
export INTERMEDIATE_CA_BUNDLE_PATH
export ROOT_CA_PATH
echo "Exported environment variables:
  HOST_KEY_PATH
  HOST_CERT_PATH
  HOST_CERT_BUNDLE_PATH
  INTERMEDIATE_CA_BUNDLE_PATH
  ROOT_CA_PATH
"
