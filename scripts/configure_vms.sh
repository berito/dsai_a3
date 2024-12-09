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

# Constant configuration values
HOST_DIR="/home/ai-server-02/code_repo/dsai_a3"
GUEST_DIR="/mnt/shared"
PACKAGES="curl git vim nfs-common openmpi-bin openmpi-common libopenmpi-dev"
NETWORK_TYPE="Bridged"

# Function to get the names of all existing VMs using VBoxManage
get_vms() {
  VBoxManage list vms | awk -F'"' '{print $2}' || log_error "Failed to retrieve VM list."
}

# Function to check if the VM is running
is_vm_running() {
  VM_NAME="$1"
  state=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep "VMState=" | cut -d'=' -f2)
  [ "$state" == "\"running\"" ]
}

configure_network() {
  VM_NAME="$1"
  
  # Store the network type in a variable
  NETWORK_TYPE="Bridged"  # Change this to "NAT" or "Bridged" as required

  # Debugging: Check if NETWORK_TYPE is set correctly
  if [ -z "$NETWORK_TYPE" ]; then
    log_error "Network type is not specified. Please provide 'NAT' or 'Bridged'."
  fi

  echo "Configuring network type $NETWORK_TYPE for VM $VM_NAME..."
  
  if [ "$NETWORK_TYPE" == "NAT" ]; then
    VBoxManage modifyvm "$VM_NAME" --nic1 nat || log_error "Failed to configure NAT for VM $VM_NAME"
    log_success "Network configured for VM $VM_NAME using NAT."
  elif [ "$NETWORK_TYPE" == "Bridged" ]; then
    VBoxManage modifyvm "$VM_NAME" --nic1 bridged || log_error "Failed to configure Bridged network for VM $VM_NAME"
    log_success "Network configured for VM $VM_NAME using Bridged."
  else
    log_error "Unsupported network type $NETWORK_TYPE. Use 'NAT' or 'Bridged'."
  fi
}

# Function to configure static IP for the VM
configure_static_ip() {
  VM_NAME="$1"
  STATIC_IP="$2"
  echo "Configuring static IP $STATIC_IP for VM $VM_NAME..."
  
  # Ensure the VM is running
  if ! is_vm_running "$VM_NAME"; then
    log_error "VM $VM_NAME is not running. Cannot configure static IP."
  fi
  
  ssh ubuntu@"$VM_NAME" <<EOF
    sudo bash -c 'echo "network:
      version: 2
      renderer: networkd
      ethernets:
        enp2s0:
          dhcp4: no
          addresses:
            - $STATIC_IP/24" > /etc/netplan/01-netcfg.yaml'
    sudo netplan apply
EOF
  
  log_success "Static IP $STATIC_IP configured for VM $VM_NAME."
}

# Function to check if the shared folder is mounted
is_shared_folder_mounted() {
  VM_NAME="$1"
  SHARED_FOLDER_NAME="shared"
  
  # List all shared folders for the VM and check if the folder is already mounted
  shared_folders=$(VBoxManage showvminfo "$VM_NAME" --details | grep "SharedFolder")
  
  if echo "$shared_folders" | grep -q "$SHARED_FOLDER_NAME"; then
    return 0  # Shared folder already mounted
  else
    return 1  # Shared folder not mounted
  fi
}

# Function to mount directories between host and guest
mount_directories() {
  VM_NAME="$1"
  SHARED_FOLDER_NAME="shared"

  # Try to remove the existing shared folder (if it exists)
  echo "Removing existing shared folder '$SHARED_FOLDER_NAME' (if any)..."
  VBoxManage sharedfolder remove "$VM_NAME" --name "$SHARED_FOLDER_NAME" 2>/dev/null

  # Add the shared folder
  echo "Mounting $HOST_DIR to $GUEST_DIR on VM $VM_NAME..."
  VBoxManage sharedfolder add "$VM_NAME" --name "$SHARED_FOLDER_NAME" --hostpath "$HOST_DIR" --automount || log_error "Failed to mount directory for VM $VM_NAME."
  log_success "Directory $HOST_DIR mounted to $GUEST_DIR on VM $VM_NAME."
}

# Function to install packages in the guest OS
install_packages() {
  VM_NAME="$1"
  echo "Installing packages on VM $VM_NAME: $PACKAGES..."
  
  if is_vm_running "$VM_NAME"; then
    ssh ubuntu@"$VM_NAME" "sudo apt update && sudo apt install -y $PACKAGES" || log_error "Failed to install packages on VM $VM_NAME"
    log_success "Packages installed on VM $VM_NAME."
  else
    log_error "VM $VM_NAME is not running. Cannot install packages."
  fi
}

# Main Function
main() {
  ACTION="$1"
  
  if [ -z "$ACTION" ]; then
    log_error "Action parameter is required (setup/install)."
  fi

  VM_NAMES=$(get_vms)
  if [ -z "$VM_NAMES" ]; then
    log_error "No VMs available to configure."
  fi
  
  VM_COUNTER=1  # For static IP assignment
  
  for VM_NAME in $VM_NAMES; do
    STATIC_IP="192.168.1.$((VM_COUNTER))"
     case "$ACTION" in
      setup)
        echo "Setting up network and shared directory for VM: $VM_NAME"
        configure_network "$VM_NAME"
        mount_directories "$VM_NAME"
        ;;
      install)
        echo "Installing packages on VM: $VM_NAME"
        install_packages "$VM_NAME"
        ;;
      static_ip)
        echo "Configuring static IP for VM: $VM_NAME"
        configure_static_ip "$VM_NAME" "$STATIC_IP"
        ;;
      *)
        log_error "Unsupported action: $ACTION. Use 'setup', 'install', or 'static_ip'."
        ;;
    esac
    
    VM_COUNTER=$((VM_COUNTER + 1))
  done
  
  log_success "Action '$ACTION' completed for all VMs!"
}

# Run the script
main "$@"
