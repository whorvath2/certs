#!/bin/zsh

function revoke_cert() {
  if openssl ca \
    -config "$OPENSSL_CONF_PATH" \
    -revoke "$HOST_CERT_PATH" \
    -passin "file:$OPENSSL_PASSIN_PATH" 1> -  ;
  then
    echo "Certificate successfully revoked! Archiving..."
    if ! mv "$HOST_KEY_PATH" "$REVOKED_CERTS_DIR/${HOST_KEY_PATH:t}.$(date +%s)" ;
    then
      echo "Error: unable to move revoked certificate at $HOST_KEY_PATH" &> -
      return 1
    fi
  else
    echo "Error: unable to revoke existing certificate" &> -
    vared -p 'Ignore and continue? ' -c keep_going
    re='^[yY][eE]?[sS]?$'
    if [[ $keep_going =~ $re ]]
    then
      echo "...Continuing creation new certificate"
    else
      return 1
    fi
  fi
  return 0
}

function test_revoke_cert() {
  openssl_conf_path="$OPENSSL_CONF_PATH"
  host_cert_path="$HOST_CERT_PATH"
  openssl_passin_path="$OPENSSL_PASSIN_PATH"
  revoked_certs_dir="$REVOKED_CERTS_DIR"
  host_key_path="$HOST_KEY_PATH"
  unset OPENSSL_CONF_PATH
  unset HOST_CERT_PATH
  unset OPENSSL_PASSIN_PATH
  unset REVOKED_CERTS_DIR
  unset HOST_KEY_PATH
  export OPENSSL_CONF_PATH="/var/temp/open_ssl_fake.conf"
  export HOST_CERT_PATH="/var/temp/"
  export OPENSSL_PASSIN_PATH=
  export REVOKED_CERTS_DIR=
  export HOST_KEY_PATH=
}