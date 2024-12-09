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

# Function to verify if VirtualBox is installed
verify_virtualbox() {
  vboxmanage --version || log_error "VirtualBox is not installed. Please install VirtualBox first."
  log_success "VirtualBox installation verified."
}

# Function to clone a VM and modify its configuration
clone_vm() {
  ORIGINAL_VM_NAME="$1"
  CLONE_VM_NAME="$2"
  MEMORY="$3"
  CPUS="$4"
  echo "Cloning VM $ORIGINAL_VM_NAME to $CLONE_VM_NAME..."
  
  # Clone the VM
  vboxmanage clonevm "$ORIGINAL_VM_NAME" --name "$CLONE_VM_NAME" --register || log_error "Failed to clone VM $ORIGINAL_VM_NAME"
  
  # Modify VM configuration (memory, CPUs)
  vboxmanage modifyvm "$CLONE_VM_NAME" --memory "$MEMORY" --cpus "$CPUS" || log_error "Failed to modify VM $CLONE_VM_NAME configuration"
  
  # Set network adapter to communicate among clones
  vboxmanage modifyvm "$CLONE_VM_NAME" --nic1 intnet --intnet1 "vmnet" || log_error "Failed to set up network for VM $CLONE_VM_NAME"
  
  log_success "VM $CLONE_VM_NAME cloned, configured with $MEMORY MB RAM, $CPUS CPUs, and network setup."
}

# Main script to clone multiple VMs
clone_multiple_vms() {
  ORIGINAL_VM_NAME="$1"
  NUM_CLONES="$2"
  MEMORY="$3"
  CPUS="$4"

  for i in $(seq 1 "$NUM_CLONES"); do
    CLONE_VM_NAME="node_$i"
    
    # Clone the VM
    clone_vm "$ORIGINAL_VM_NAME" "$CLONE_VM_NAME" "$MEMORY" "$CPUS"
      
    echo "Finished setting up $CLONE_VM_NAME."
  done
}

# Run the script with required parameters from command line
main() {
  # Check if the required arguments are passed
  if [ $# -lt 3 ]; then
    echo "Usage: $0 <num_clones> <memory_in_MB> <cpus>"
    exit 1
  fi

  # Parameters from command line
  NUM_CLONES="$1"
  MEMORY="$2"
  CPUS="$3"
  
  # Set the original VM name (hardcoded as master in this case)
  ORIGINAL_VM_NAME="master"

  # Verify VirtualBox installation
  verify_virtualbox
  
  # Clone and configure multiple VMs
  clone_multiple_vms "$ORIGINAL_VM_NAME" "$NUM_CLONES" "$MEMORY" "$CPUS"
}

# Run the main function
main "$@"
