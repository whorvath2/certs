#!/bin/zsh

check_path () {
  # Accepts a list of one or more filepaths to be tested as arguments, and returns 0 if they all exist in the file system; 1 otherwise.
  if [[ $# == 0 ]]
  then
    echo "Usage: check_path <file path 1> [...]"
    return 1
  fi
  for item in ${argv[1,$#]}
  do
    if ! [[ -a "${item}" ]] ;
    then
      echo "Error: file at ${item} does not exist."
      return 1
    fi
  done
  return 0
}

test_check_path () {
  # Unit test for check_path()
  filepath="./foo.tmp"
  touch "$filepath"
  if ! check_path "$filepath" &>/dev/null
  then
    echo "Error: check_path did not find temporary file at $filepath"
    rm "$filepath" # May not succeed; that's OK for now
    return 1
  else
    echo "Works for single parameter..."
  fi

  secondpath="./bar.tmp"
  touch "$secondpath"
  if ! check_path "$filepath" "$secondpath" &>/dev/null
  then
    echo "Error: check_path did not find temporary files at $filepath and $secondpath"
    rm -f "$filepath" # May not succeed; that's OK for now
    rm -f "$secondpath" # Also may not succeed
    return 1
  else
    echo "Works for multiple parameters..."
  fi

  rm -f "$filepath"
  rm -f "$secondpath"

  if check_path "$filepath" "$secondpath" &>/dev/null
  then
    echo "Error: check_path returned success code for checking non-existent files at $filepath and $secondpath"
    return 1
  else
    echo "Works for non-existent files..."
  fi
  echo "Success: testing check_path"
  return 0
}