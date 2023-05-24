#!/bin/zsh

function generate_csr() {
  echo "Creating certificate signing request..."
  CERT_SUBJ="/C=$COUNTRY/ST=$STATE/L=$LOCALE/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$HOST_NAME"
  echo "  CSR subject: $CERT_SUBJ
  Adding alternative names..."
  if [[ $# -gt 1 ]] ;
  then
    sans="subjectAltName = @alt_names\n\n[alt_names]\n"
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
    -subj "$CERT_SUBJ" 1> -  ;
  then
    echo "Error: creating certificate signing request failed" &> -
    remove_path "$HOST_CSR_PATH"
    return 1
  fi
  if ! check_path "$HOST_CSR_PATH"
  then
    echo "Error: file at $HOST_CSR_PATH is missing"
    return 1
  fi
  return 0
}

function test_generate_csr() {
  $HOST_CSR_PATH
  $COUNTRY
  $STATE
  $LOCALE
  $ORGANIZATION
  $ORGANIZATIONAL_UNIT
  $HOST_NAME
  $CERT_SUBJ
  $OPENSSL_EXT_PATH
  $TEMP_EXT_PATH
}