#!/bin/zsh
# Creates a secret in the local podman instance.

create_secret () {
  if [[ $# == 0 ]]
  then
    echo "Usage: create_secret <secret name> <path to source file> [error code]"
    return 1
  fi
  echo "Creating podman secret $1...Checking podman vm..."
  if ! source "$THIS_DIR/podman_vm.sh" && start_vm ;
  then
    echo "Error: podman vm not running"
    return 1
  fi
  if ! podman secret create "$1" "$2" ;
  then
    echo "Error creating secret named $1!"
    source "$THIS_DIR/check_err_code.sh"
    code=$(check_err_code $3)
    return $code
  fi
  echo "Success: secret $1 created"
  return 0
}