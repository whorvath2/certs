#!/bin/zsh
# Returns 0 if the filepath specified as the first argument exists in the file system. If the filepath does not exist
# and the optional second (error code) argument is supplied and is between 0 and 254, that error code is returned;
# otherwise this function returns 1.


check_path () {
  if [[ $# == 0 ]]
  then
    echo "Usage: check_path <file path> [error code]"
    return 1
  fi
  if ! [[ -a "$1" ]]
  then
    echo "$1 does not exist!"
    source "$THIS_DIR/check_err_code.sh"
    code=$(check_err_code $2)
    return $code
  else
    echo "Found $1"
    return 0
  fi
}
