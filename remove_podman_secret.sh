#!/bin/zsh

remove_secret () {
  if [[ $# == 0 ]]
  then
    echo "Usage: remove_secret <secret name> [error code on failure]"
    return 1
  fi
  echo "Removing podman secret $1...Checking podman vm..."
  source "$THIS_DIR/podman_vm.sh"
  start_vm
  existing_secrets=$(podman secret ls)
  if echo "$existing_secrets" | grep "$1" ;
  then
    if ! podman secret rm "$1"
    then
      echo "Error removing secret named $1!"
      source "$THIS_DIR/check_err_code.sh"
      code=$(check_err_code $2)
      return $code
    fi
  fi
  return 0
}