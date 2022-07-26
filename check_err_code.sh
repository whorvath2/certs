#!/bin/zsh
# Returns the first argument if it's a number between 0 and 254; otherwise returns 1. This function is designed to be
# used to validate error codes passed as arguments to other functions.

re='^[1-9]+$'
check_err_code () {
  if [[ $# == 0 ]]
  then
    return 1
  elif ! [[ $1 =~ $re ]]
  then
    return 1
  fi
  if [[ $1 -lt 255 && $1 -gt 0 ]] ; then
    return $1
  fi
  return 1
}