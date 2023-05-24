#!/bin/zsh
# Checks if a default podman VM is currently running and starts it if it isn't.

default_machine () {
  # Find the nam of the default podman machine in this environment.
  if ! podman machine list --noheading --format="{{.Name}}\t{{.Default}}" | \
    while IFS= read -r line
    do
      if [[ $(echo "$line" | grep -E "true") == 0 ]]
      then
        echo "$line" | sed 's/\t.*//'
        return
      fi
    done
  then
    echo ""
    return
  fi
  echo "podman-machine-default"
}

start_vm () {
  # Get the default podman machine and return an error if there is none
  machine_name=${1:-$(default_machine)}
  if ! [[ -n "$machine_name" ]]
  then
    echo "Error: no default podman machine name found"
    return 1
  fi

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
          echo "Error: $machine_name failed to start" &>/dev/null
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
    echo "Error: $machine_name is not a known podman machine" &>/dev/null
    return 1
  fi
  echo "Success: Podman machine $machine_name is running"
  return 0
}