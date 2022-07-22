#!/bin/zsh

existing_secrets=$(podman secret ls)
remove_secret () {
  if (( $# == 0 ))
  then
    echo "Usage: remove_secret <secret name> [error code on failure]"
    exit 1
  fi
  echo "$existing_secrets" | grep "$1"
  if [[ $(echo $?) -eq 0 ]]
  then
    podman secret rm "$1"
    if [[ $(echo $?) -ne 0 ]]
    then
      echo "Error removing secret named $1!"
      if (( $2 != 0 ))
      then
        exit $2
      else
        exit 1
      fi
    fi
  fi
}