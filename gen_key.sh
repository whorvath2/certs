#!/bin/zsh

generate_key() {
  echo "Generating RSA key to $HOST_KEY_PATH"
  if ! openssl genrsa -out "$HOST_KEY_PATH" 4096 1> -  ;
  then
    echo "Error: $HOST_NAME key generation failed" &> -
    return 1
  else
    echo "Generated key at $HOST_KEY_PATH" &> -
  fi
  return 0
}

test_generate_key() {
  echo "Testing generate_key"
  host_key_path="$HOST_KEY_PATH"
  host_name="$HOST_NAME"
  unset HOST_KEY_PATH
  unset HOST_NAME
  export HOST_KEY_PATH="/var/tmp/test_key_do_not_use.pem"
  export HOST_NAME="aTestHostName"
  return_val=1
  # Run function to be tested
  generate_key
  val=$?
  if [[ $val -eq 0 && -s $HOST_KEY_PATH && -f $HOST_KEY_PATH ]]
  then
    echo "Test succeeded!"
    return_val=0
  else
    echo "Test failed!"
  fi
  rm "$HOST_KEY_PATH"
  unset HOST_KEY_PATH
  unset HOST_NAME
  export HOST_KEY_PATH="$host_key_path"
  export HOST_NAME="$host_name"
  return $return_val
}
