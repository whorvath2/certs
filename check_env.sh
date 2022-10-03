#!/bin/zsh

if ! podman --version &>/dev/null ;
then
  echo "podman is missing"
  return 1
fi

if ! openssl version &>/dev/null ;
then
  echo "openssl is missing"
  return 1
fi

if ! [[ \
 -n $COUNTRY \
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
   return 1
fi
return 0