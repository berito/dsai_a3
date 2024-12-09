#!/bin/bash

# Function to log success messages
log_success() {
  echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to log error messages with detailed parameter order information
log_error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
  exit 1
}

# Function to clone a VM
clone_vm() {
  ORIGINAL_VM_NAME="$1"
  CLONE_VM_NAME="$2"
  
  # Clone the VM using VirtualBox CLI
  echo "Cloning $ORIGINAL_VM_NAME to $CLONE_VM_NAME..."
  vboxmanage clonevm "$ORIGINAL_VM_NAME" --name "$CLONE_VM_NAME" --register || log_error "Failed to clone $ORIGINAL_VM_NAME to $CLONE_VM_NAME"
  
  # Modify the memory and CPU for the cloned VM
  modify_vm "$CLONE_VM_NAME" "$3" "$4"
  
  log_success "VM $CLONE_VM_NAME cloned and modified successfully."
}

# Function to modify an existing VM's memory and CPU
modify_vm() {
  VM_NAME="$1"
  MEMORY="$2"
  CPUS="$3"

  # Validate memory and CPU values
  if [ "$MEMORY" -lt 4 ]; then
    log_error "Invalid memory size: $MEMORY MB. It must be at least 4 MB. (Order: MEMORY, CPUS)"
  fi
  if [ "$MEMORY" -gt 2097152 ]; then
    log_error "Invalid memory size: $MEMORY MB. It must be less than 2,097,152 MB. (Order: MEMORY, CPUS)"
  fi
  if [ "$CPUS" -lt 1 ]; then
    log_error "Invalid CPU count: $CPUS. It must be at least 1 CPU. (Order: MEMORY, CPUS)"
  fi

  echo "Updating VM $VM_NAME with $MEMORY MB memory and $CPUS CPUs..."
  vboxmanage modifyvm "$VM_NAME" --memory "$MEMORY" --cpus "$CPUS" || log_error "Failed to update $VM_NAME with $MEMORY MB memory and $CPUS CPUs"
  
  log_success "VM $VM_NAME updated with $MEMORY MB memory and $CPUS CPUs."
}

# Function to check the last node's number and find the next available clone name
get_next_clone_name() {
  # List all VMs, filter for nodes (node_1, node_2, ...), and extract the highest node number
  existing_nodes=$(vboxmanage list vms | grep -E 'node_' | awk -F '"' '{print $2}' | sed 's/node_//g')
  
  # If there are existing nodes, find the highest number
  if [ -z "$existing_nodes" ]; then
    next_node=1  # If no existing nodes, start with node_1
  else
    next_node=$(echo "$existing_nodes" | sort -n | tail -n 1)
    next_node=$((next_node + 1))  # Increment the last node number to create the new node
  fi
  
  # Return the next clone name
  echo "node_$next_node"
}

# Function to create clones based on the provided parameters
create_clones() {
  ORIGINAL_VM_NAME="$1"
  NUM_CLONES="$2"
  MEMORY="$3"
  CPUS="$4"

  # Check if the original VM exists
  vboxmanage list vms | grep -q "$ORIGINAL_VM_NAME" || log_error "Original VM ($ORIGINAL_VM_NAME) does not exist."
  
  # Create clones
  for i in $(seq 1 "$NUM_CLONES"); do
    # Get the next available clone name
    CLONE_VM_NAME=$(get_next_clone_name)
    
    # Clone the VM and modify memory and CPUs
    clone_vm "$ORIGINAL_VM_NAME" "$CLONE_VM_NAME" "$MEMORY" "$CPUS"
    echo "Finished cloning $CLONE_VM_NAME."
  done
}

# Function to update master VM
update_master_vm() {
  MEMORY="$1"
  CPUS="$2"
  
  # Update master VM
  modify_vm "master" "$MEMORY" "$CPUS"
}

# Function to update all node VMs
update_node_vms() {
  MEMORY="$1"
  CPUS="$2"
  
  # Get the list of all node VMs
  node_vms=$(vboxmanage list vms | grep -E 'node_' | awk -F '"' '{print $2}')
  
  for vm in $node_vms; do
    modify_vm "$vm" "$MEMORY" "$CPUS"
  done
}

# Validate if sufficient parameters are passed for the action
if [ $# -lt 2 ]; then
  log_error "Insufficient parameters. Please provide ACTION (clone, update_master, or update_nodes), and appropriate parameters."
fi

ACTION="$1"

# Run the corresponding function based on the action parameter
case "$ACTION" in
  "clone")
    # Ensure that all necessary parameters are provided for cloning
    if [ $# -ne 4 ]; then
      log_error "For 'clone', you need to provide 4 parameters: ACTION (clone), NUM_CLONES, MEMORY, and CPUS. Example: ./script.sh clone 5 1024 2"
    fi
    NUM_CLONES="$2"
    MEMORY="$3"
    CPUS="$4"
    # Create clones of the master VM
    ORIGINAL_VM_NAME="master"  # Modify this if the original VM name changes
    create_clones "$ORIGINAL_VM_NAME" "$NUM_CLONES" "$MEMORY" "$CPUS"
    ;;
  "update_master")
    # Ensure that only memory and CPU are provided for updating master VM
    if [ $# -ne 3 ]; then
      log_error "For 'update_master', you need to provide 3 parameters: ACTION (update_master), MEMORY, and CPUS. Example: ./script.sh update_master 1024 2"
    fi
    MEMORY="$2"
    CPUS="$3"
    # Update the master VM only
    update_master_vm "$MEMORY" "$CPUS"
    ;;
  "update_nodes")
    # Ensure that only memory and CPU are provided for updating node VMs
    if [ $# -ne 3 ]; then
      log_error "For 'update_nodes', you need to provide 3 parameters: ACTION (update_nodes), MEMORY, and CPUS. Example: ./script.sh update_nodes 1024 2"
    fi
    MEMORY="$2"
    CPUS="$3"
    # Update all node VMs
    update_node_vms "$MEMORY" "$CPUS"
    ;;
  *)
    log_error "Invalid action specified. Use 'clone', 'update_master', or 'update_nodes'."
    ;;
esac
