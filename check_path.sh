#!/bin/zsh

check_path () {
  if [[ $# == 0 ]]
  then
    echo "Usage: check_path <file path> [error code]"
    exit 0
  fi
  if ! [[ -a "$1" ]]
  then
    echo "$1 does not exist!"
    source check_err_code.sh
    code=$(check_err_code $2)
    exit $code
  fi
}