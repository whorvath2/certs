#!/bin/zsh

create_secret () {
  if [[ $# == 0 ]]
  then
    echo "Usage: create_secret <secret name> <path to source file> [error code]"
    exit 0
  fi

  podman secret create "$1" "$2"
  if [[ $? != 0 ]]
  then
    echo "Error creating secret named $1!"
    source check_err_code.sh
    exit "$(check_err_code $3)"
  fi
}