#!/bin/zsh

function remove_path () {
  if [[ -a "$1" ]]
  then
    rm "$1"
  fi
}

function test_remove_path() {
  echo "Testing remove_path..."
  fake_file=$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c20)
  fake_path="/var/tmp/$fake_file"
  # The file shouldn't exist, but remove_path should return 0
  if ! remove_path "$fake_path"
  then
    echo "Error: remove_path returned >0 when using non-existent file $fake_path"
    return 1
  fi
  touch "$fake_path"
  if ! [[ -a "$fake_path" ]]
  then
    echo "Error: test failed creating fake empty file at $fake_path"
    return 2
  fi
  if ! remove_path "$fake_path"
  then
    echo "Error: test failed removing fake empty file at $fake_path"
    return 3
  fi
  echo "Test succeeded"
  return 0
}
