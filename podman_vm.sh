#!/bin/zsh
# Checks if a named podman VM is currently running and starts it if it isn't. If no VM name is specified, the default
# machine is used.

default_machine () {
  podman machine list --noheading --format="{{.Name}}\t{{.Default}}" | \
    while IFS= read -r line
    do
      if [[ $(echo "$line" | grep -E "true") == 0 ]]
      then
        echo "$line" | sed 's/\t.*//'
        return
      fi
    done
  echo "podman-machine-default"
}

start_vm () {
  machine_name=${1:-$(default_machine)}
  echo "Checking for $machine_name..."
  local found=0
  while read -r line
  do
    if echo "$line" | grep -q "$machine_name" ;
    then
      found=1
      echo "$machine_name found. Checking running status..."
      if echo "$line" | grep -q "false" ;
      then
        echo "...$machine_name is not running. Starting..."
        if ! podman machine start "$machine_name" ;
        then
          echo "Error: $machine_name failed to start" >&2;
          return 1
        fi
      else
        echo "Success: $machine_name is already running"
        return 0
      fi
    fi
  done < <(podman machine list --noheading --format="{{.Name}}\t{{.Running}}")
  if [[ $found -eq 0 ]]
  then
    echo "Error: $machine_name is not a known podman machine" >&2;
    return 1
  fi
  echo "Success: Podman machine $machine_name is running"
  return 0
}