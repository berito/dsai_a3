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
HOST_DIR="/home/user/shared"       # Host directory to mount
GUEST_DIR="/mnt/shared"            # Guest directory to mount
PACKAGES="curl git vim nfs-common openmpi-bin openmpi-common libopenmpi-dev"            # Packages to install
NETWORK_TYPE="Bridged"             # Network type (NAT or Bridged)

# Function to get the names of all existing VMs using VBoxManage
get_vms() {
  # List all VMs using VBoxManage
  vms=$(VBoxManage list vms | awk -F'"' '{print $2}')
  
  if [ -z "$vms" ]; then
    log_error "No VMs found."
  fi
  
  echo "$vms"
}

# Function to check if the VM is running
is_vm_running() {
  VM_NAME="$1"
  
  # Check if the VM is running using VBoxManage
  state=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep "VMState=" | cut -d'=' -f2)
  
  if [ "$state" == "\"running\"" ]; then
    return 0  # VM is running
  else
    return 1  # VM is not running
  fi
}

# Function to configure static IP for the guest VM (Ubuntu example)
configure_static_ip() {
  VM_NAME="$1"
  STATIC_IP="$2"
  
  echo "Configuring static IP $STATIC_IP for VM $VM_NAME..."
  
  # This assumes your VMs are Ubuntu-based and use netplan for networking.
  # Modify this if you are using a different OS or network manager.
  
  ssh ubuntu@"$VM_NAME" <<EOF
    sudo bash -c 'echo "network:
      version: 2
      renderer: networkd
      ethernets:
        eth0:
          dhcp4: no
          addresses:
            - $STATIC_IP/24" > /etc/netplan/01-netcfg.yaml'
    sudo netplan apply
EOF
  
  log_success "Static IP $STATIC_IP configured for VM $VM_NAME."
}

# Function to install packages in the guest OS
install_packages() {
  VM_NAME="$1"
  
  echo "Installing packages on VM $VM_NAME: $PACKAGES..."
  
  ssh ubuntu@"$VM_NAME" "sudo apt update && sudo apt install -y $PACKAGES" || log_error "Failed to install packages on VM $VM_NAME"
  
  log_success "Packages installed on VM $VM_NAME."
}

# Function to mount directories between host and guest
mount_directories() {
  VM_NAME="$1"
  
  echo "Mounting $HOST_DIR to $GUEST_DIR on VM $VM_NAME..."
  
  VBoxManage sharedfolder add "$VM_NAME" --name shared --hostpath "$HOST_DIR" --automount || log_error "Failed to mount directory."
  
  log_success "Directory $HOST_DIR mounted to $GUEST_DIR on VM $VM_NAME."
}

# Function to configure the network for the VM
configure_network() {
  VM_NAME="$1"
  
  echo "Configuring network type $NETWORK_TYPE for VM $VM_NAME..."
  
  if [ "$NETWORK_TYPE" == "NAT" ]; then
    VBoxManage modifyvm "$VM_NAME" --nic1 nat || log_error "Failed to configure NAT for VM $VM_NAME"
  elif [ "$NETWORK_TYPE" == "Bridged" ]; then
    VBoxManage modifyvm "$VM_NAME" --nic1 bridged || log_error "Failed to configure Bridged network for VM $VM_NAME"
  else
    log_error "Unsupported network type $NETWORK_TYPE"
  fi
  
  log_success "Network configured for VM $VM_NAME using $NETWORK_TYPE."
}

# Function to configure a VM
configure_vm() {
  VM_NAME="$1"
  
  # Assign sequential static IP starting from 192.168.1.1, 192.168.1.2, and so on
  STATIC_IP="192.168.1.$((VM_COUNTER))"
  
  configure_network "$VM_NAME"
  configure_static_ip "$VM_NAME" "$STATIC_IP"
  mount_directories "$VM_NAME"
  install_packages "$VM_NAME"
  
  log_success "VM $VM_NAME has been configured successfully."
}

# Main Function
main() {
  echo "Getting list of existing VMs..."

  VM_NAMES=$(get_vms)  # Dynamically get the VM names

  if [ -z "$VM_NAMES" ]; then
    log_error "No VMs available to configure."
  fi

  # Counter for running VMs
  RUNNING_VM_COUNT=0
  TOTAL_VM_COUNT=0
  VM_COUNTER=1  # Static IP starting from 192.168.1.1
  
  # Loop through each VM and check if it's running
  for VM_NAME in $VM_NAMES; do
    TOTAL_VM_COUNT=$((TOTAL_VM_COUNT + 1))
    
    if is_vm_running "$VM_NAME"; then
      RUNNING_VM_COUNT=$((RUNNING_VM_COUNT + 1))
      echo "VM $VM_NAME is running. Configuring..."
      configure_vm "$VM_NAME"
      VM_COUNTER=$((VM_COUNTER + 1))  # Increment IP for the next VM
    else
      echo "VM $VM_NAME is not running. Skipping configuration."
    fi
  done

  echo -e "\e[32m$RUNNING_VM_COUNT out of $TOTAL_VM_COUNT VMs are running and configured successfully!\e[0m"
}

# Run the main function
main
