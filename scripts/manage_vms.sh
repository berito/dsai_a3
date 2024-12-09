#!/bin/bash

# Function to log success messages
log_success() {
  echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to log error messages
log_error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
  exit 1
}

# Function to get the names of all VMs (including clones)
get_vms() {
  # List all VMs and filter based on the naming pattern "master" or "node_"
  vms=$(vboxmanage list vms | grep -E 'master|node_' | awk -F '"' '{print $2}')

  if [ -z "$vms" ]; then
    log_error "No VMs found."
  fi
  
  echo "$vms"
}

# Function to get the names of all running VMs
get_running_vms() {
  # List all running VMs
  running_vms=$(vboxmanage list runningvms | awk -F '"' '{print $2}')

  echo "$running_vms"
}

# Function to stop all running VMs
stop_all_running_vms() {
  # Get the names of all running VMs
  running_vms=$(get_running_vms)

  if [ -z "$running_vms" ]; then
    log_success "No running VMs to stop."
  else
    for vm in $running_vms; do
      echo "Stopping the VM $vm..."
      vboxmanage controlvm "$vm" poweroff || log_error "Failed to stop VM $vm"
      log_success "VM $vm stopped."
    done
  fi
}

# Function to start all stopped VMs
start_all_stopped_vms() {
  # Get the names of all VMs
  vms=$(get_vms)
  
  # Get the names of all running VMs
  running_vms=$(get_running_vms)

  # Loop through all VMs and start those that are not running
  for vm in $vms; do
    if [[ ! " $running_vms " =~ " $vm " ]]; then
      echo "Starting the VM $vm in headless mode..."
      vboxmanage startvm "$vm" --type headless || log_error "Failed to start VM $vm"
      log_success "VM $vm started in headless mode."
    fi
  done
}

# Function to list all VMs
list_all_vms() {
  echo "Listing all VMs:"
  get_vms
}

# Function to list all running VMs
list_running_vms() {
  echo "Listing running VMs:"
  running_vms=$(get_running_vms)
  
  if [ -z "$running_vms" ]; then
    echo "No VMs are running."
  else
    echo "$running_vms"
  fi
}

# Main script to start, stop, list all VMs or run specific actions
manage_vms() {
  ACTION="$1"
  
  if [ "$ACTION" != "start" ] && [ "$ACTION" != "stop" ] && [ "$ACTION" != "list" ] && [ "$ACTION" != "listall" ]; then
    log_error "Invalid parameter. Please specify 'start', 'stop', 'list', or 'listall'."
  fi
  
  if [ "$ACTION" == "start" ]; then
    start_all_stopped_vms
  elif [ "$ACTION" == "stop" ]; then
    stop_all_running_vms
  elif [ "$ACTION" == "list" ]; then
    list_running_vms
  elif [ "$ACTION" == "listall" ]; then
    list_all_vms
  fi
}

# Check if the action parameter is provided
if [ $# -eq 0 ]; then
  log_error "Please provide an action: 'start', 'stop', 'list', or 'listall'."
fi

# Run the manage_vms function with the specified action
manage_vms "$1"
