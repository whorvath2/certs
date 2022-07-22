#!/bin/zsh
re='^[1-9]+$'

check_err_code () {
  if [[ $# == 0 ]]
  then
    return 1
  elif ! [[ $1 =~ $re ]]
  then
    return 1
  fi
  return $1
}
