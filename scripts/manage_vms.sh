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

# Function to get the names of all stopped VMs (not running)
get_stopped_vms() {
  # List all VMs and filter out the running ones to get stopped ones
  stopped_vms=$(get_vms | grep -v -f <(get_running_vms))

  echo "$stopped_vms"
}

# Function to start a specific VM in headless mode
start_vm() {
  VM_NAME="$1"
  echo "Starting the VM $VM_NAME in headless mode..."
  
  vboxmanage startvm "$VM_NAME" --type headless || log_error "Failed to start VM $VM_NAME"
  
  log_success "VM $VM_NAME started in headless mode."
}

# Function to stop a specific VM
stop_vm() {
  VM_NAME="$1"
  echo "Stopping the VM $VM_NAME..."
  
  vboxmanage controlvm "$VM_NAME" poweroff || log_error "Failed to stop VM $VM_NAME"
  
  log_success "VM $VM_NAME stopped."
}

# Function to list all VMs (running and stopped)
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

# Function to manage all running VMs (stop them)
stop_all_running_vms() {
  running_vms=$(get_running_vms)

  if [ -z "$running_vms" ]; then
    log_error "No running VMs to stop."
  fi

  for vm in $running_vms; do
    stop_vm "$vm"
  done
}

# Function to start all VMs that are not running
start_all_non_running_vms() {
  stopped_vms=$(get_stopped_vms)

  if [ -z "$stopped_vms" ]; then
    echo "All VMs are already running."
    return 0
  fi

  for vm in $stopped_vms; do
    start_vm "$vm"
  done
}

# Main script to start, stop, list all VMs or run specific actions
manage_vms() {
  ACTION="$1"
  
  if [ "$ACTION" != "start" ] && [ "$ACTION" != "stop" ] && [ "$ACTION" != "list" ] && [ "$ACTION" != "list_running" ]; then
    log_error "Invalid parameter. Please specify 'start', 'stop', 'list', or 'listall'."
  fi
  
  if [ "$ACTION" == "start" ]; then
    start_all_non_running_vms
  elif [ "$ACTION" == "stop" ]; then
    stop_all_running_vms
  elif [ "$ACTION" == "list_running" ]; then
    list_running_vms
  elif [ "$ACTION" == "list" ]; then
    list_all_vms
  fi
}

# Check if the action parameter is provided
if [ $# -eq 0 ]; then
  log_error "Please provide an action: 'start', 'stop', 'list', or 'list_running'."
fi

# Run the manage_vms function with the specified action
manage_vms "$1"
