#!/bin/bash

# Function to display success messages
log_success() {
  echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to log error messages and exit
log_error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
  exit 1
}

# Function to verify if VirtualBox is installed
verify_virtualbox() {
  echo "Verifying VirtualBox installation..."
  vboxmanage --version || log_error "VirtualBox is not installed. Please install VirtualBox first."
  log_success "VirtualBox installation verified."
}

# Function to create a virtual machine with customizable VM name, memory, and CPU count
create_vm() {
 VM_NAME="$1"
MEMORY="$2"
CPUS="$3"

if vboxmanage list vms | grep -q "\"$VM_NAME\""; then
  echo "VM with name \"$VM_NAME\" already exists."
else
  echo "Creating Virtual Machine with name: $VM_NAME, memory: $MEMORY MB, CPUs: $CPUS..."
  vboxmanage createvm --name "$VM_NAME" --ostype "Ubuntu_64" --register || log_error "Failed to create VM"
  vboxmanage modifyvm "$VM_NAME" --memory "$MEMORY" --cpus "$CPUS" --nic1 nat --audio none --boot1 dvd --vrde on || log_error "Failed to configure VM"
  log_success "Virtual Machine created and configured with name: $VM_NAME, memory: $MEMORY MB, CPUs: $CPUS."
fi
}

# Function to download Ubuntu Server ISO
download_ubuntu_iso() {
 ISO_DIR="$HOME/isos"
ISO_FILE="$ISO_DIR/ubuntu-22.04-live-server-amd64.iso"
if [ -f "$ISO_FILE" ]; then
  echo "Ubuntu Server ISO already downloaded."
else
  echo "Downloading Ubuntu Server ISO..."
  mkdir -p "$ISO_DIR"
  wget -O "$ISO_FILE" https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso || log_error "Failed to download Ubuntu Server ISO"
  log_success "Ubuntu Server ISO downloaded."
fi

}

# Function to configure VM storage
configure_storage() {
  VM_NAME="$1"
  DISK_SIZE="$2"
  DISK_FILE="$HOME/${VM_NAME}.vdi"

  if vboxmanage showvminfo "$VM_NAME" | grep -q "SATA Controller"; then
    echo "Storage for VM \"$VM_NAME\" is already configured."
  else
    echo "Configuring VM storage with disk size: $DISK_SIZE MB..."
    vboxmanage createhd --filename "$DISK_FILE" --size "$DISK_SIZE" || log_error "Failed to create virtual disk"
    vboxmanage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAHCI || log_error "Failed to add storage controller"
    vboxmanage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$DISK_FILE" || log_error "Failed to attach virtual disk"
    log_success "VM storage configured."
  fi

}

# Function to create an ISO for the preseed file
create_preseed_iso() {
  PRESEED_FILE="$1"
  PRESEED_ISO="$2"
  ISO_DIR="$HOME/preseed_iso"  # Directory to hold the preseed file for ISO creation

  # Check if the preseed ISO already exists
  if [ -f "$PRESEED_ISO" ]; then
    echo "Preseed ISO \"$PRESEED_ISO\" already created."
  else
    echo "Creating ISO for preseed file..."

    # Create the directory if it doesn't exist
    mkdir -p "$ISO_DIR"

    # Copy the preseed file into the directory
    cp "$PRESEED_FILE" "$ISO_DIR/"

    # Create the ISO using genisoimage/mkisofs with the directory and preseed file
    mkisofs -o "$PRESEED_ISO" -b "$PRESEED_FILE" "$ISO_DIR" || log_error "Failed to create preseed ISO"

    log_success "Preseed ISO created."
  fi
}

# Function to attach the preseed ISO to the VM
attach_preseed() {
  VM_NAME="$1"
  PRESEED_ISO="$2"
  if vboxmanage showvminfo "$VM_NAME" | grep -q "$PRESEED_ISO"; then
    echo "Preseed ISO \"$PRESEED_ISO\" already attached to VM \"$VM_NAME\"."
  else
    echo "Attaching preseed ISO for automated Ubuntu installation..."
    vboxmanage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$PRESEED_ISO" || log_error "Failed to attach preseed ISO"
    log_success "Preseed ISO attached."
  fi

}

# Function to start the VM in headless mode
start_vm_headless() {
    VM_NAME="$1"
    if vboxmanage showvminfo "$VM_NAME" | grep -q "State:.*running"; then
      echo "Virtual Machine \"$VM_NAME\" is already started."
    else
      echo "Starting the Virtual Machine in headless mode..."
      vboxmanage startvm "$VM_NAME" --type headless || log_error "Failed to start VM"
      log_success "Virtual Machine started in headless mode."
    fi

}

# Function to automate OS installation using the preseed ISO
automate_install() {
 VM_NAME="$1"
ISO_FILE="$2"
PRESEED_ISO="$3"  # Path to the ISO containing the preseed file

echo "Automating the installation of Ubuntu Server..."

# Check if the ISO file is already attached
if vboxmanage showvminfo "$VM_NAME" | grep -q "$ISO_FILE"; then
  echo "ISO file \"$ISO_FILE\" is already attached to the VM \"$VM_NAME\"."
else
  echo "Attaching ISO file \"$ISO_FILE\"..."
  vboxmanage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type dvddrive --medium "$ISO_FILE" || log_error "Failed to attach ISO file"
  log_success "ISO file \"$ISO_FILE\" attached."
fi

# Check if the preseed ISO is already attached
if vboxmanage showvminfo "$VM_NAME" | grep -q "$PRESEED_ISO"; then
  echo "Preseed ISO \"$PRESEED_ISO\" is already attached to the VM \"$VM_NAME\"."
else
  echo "Attaching preseed ISO for automated Ubuntu installation..."
  attach_preseed "$VM_NAME" "$PRESEED_ISO"
  log_success "Preseed ISO \"$PRESEED_ISO\" attached."
fi

echo "VM is now ready for Ubuntu installation with automated responses from preseed file."
start_vm_headless "$VM_NAME"

}

# Main Script Execution with parameters passed to the function
main() {
  verify_virtualbox

  # Define VM configuration
  VM_NAME="master"
  MEMORY=2048
  CPUS=2
  DISK_SIZE=20000  # Disk size in MB
  PRESEED_FILE="./preseed.cfg"  # Preseed file in the current directory
  PRESEED_ISO="./preseed.iso"  # Path to the preseed ISO
  
  create_vm "$VM_NAME" "$MEMORY" "$CPUS"
  download_ubuntu_iso
  configure_storage "$VM_NAME" "$DISK_SIZE"
  
  # Create the preseed ISO from the preseed file in the current directory
  create_preseed_iso "$PRESEED_FILE" "$PRESEED_ISO"
  
  # Automate installation using the preseed ISO
  automate_install "$VM_NAME" "$HOME/isos/ubuntu-22.04-live-server-amd64.iso" "$PRESEED_ISO"

  # Final Success Message
  echo -e "\e[32mAll steps completed successfully! Your headless Ubuntu Server VM is now running.\e[0m"
}

# Run the main function
main
