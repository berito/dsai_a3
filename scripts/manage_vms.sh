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
  # List all VMs and filter based on the naming pattern "node_" or your preferred naming convention
  vms=$(vboxmanage list vms | grep 'node_' | awk -F '"' '{print $2}')
  
  if [ -z "$vms" ]; then
    log_error "No VMs found."
  fi
  
  echo "$vms"
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
  
  vboxmanage controlvm "$VM_NAME" acpipowerbutton || log_error "Failed to stop VM $VM_NAME"
  
  log_success "VM $VM_NAME stopped."
}

# Main script to start or stop all VMs
manage_vms() {
  ACTION="$1"
  
  if [ "$ACTION" != "start" ] && [ "$ACTION" != "stop" ]; then
    log_error "Invalid parameter. Please specify 'start' or 'stop'."
  fi
  
  # Get the names of all VMs
  vms=$(get_vms)
  
  # Perform the specified action (start or stop) on each VM
  for vm in $vms
  do
    if [ "$ACTION" == "start" ]; then
      start_vm "$vm"
    elif [ "$ACTION" == "stop" ]; then
      stop_vm "$vm"
    fi
  done
}

# Check if the action parameter is provided
if [ $# -eq 0 ]; then
  log_error "Please provide an action: 'start' or 'stop'."
fi

# Run the manage_vms function with the specified action
manage_vms "$1"
