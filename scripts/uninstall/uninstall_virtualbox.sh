#!/bin/bash

# Function to log success messages
log_success() {
  echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to log error messages and exit
log_error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
  exit 1
}

# Function to unregister all VirtualBox VMs
unregister_vms() {
  echo "Unregistering all VirtualBox VMs..."
  vms=$(vboxmanage list vms | cut -d "{" -f 1 | tr -d '"')
  if [ -z "$vms" ]; then
    log_success "No VirtualBox VMs to unregister."
  else
    for vm in $vms; do
      echo "Unregistering VM: $vm..."
      vboxmanage unregistervm "$vm" --delete || log_error "Failed to unregister VM: $vm"
    done
    log_success "All VMs unregistered successfully."
  fi
}

# Function to uninstall VirtualBox
uninstall_virtualbox() {
  echo "Uninstalling VirtualBox..."
  sudo apt-get purge -y virtualbox* || log_error "Failed to uninstall VirtualBox"
  sudo apt-get autoremove -y || log_error "Failed to remove dependencies"
  sudo apt-get clean || log_error "Failed to clean up packages"
  log_success "VirtualBox uninstalled successfully."
}

# Function to remove VirtualBox repository
remove_repository() {
  echo "Removing VirtualBox repository..."
  sudo add-apt-repository -r -y "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" || log_error "Failed to remove repository"
  sudo apt-get update || log_error "Failed to update package list after repository removal"
  log_success "VirtualBox repository removed."
}

# Function to remove VirtualBox configuration and data files
remove_configuration_data() {
  echo "Removing VirtualBox configuration and data files..."
  rm -rf ~/.VirtualBox || log_error "Failed to remove user configuration files"
  rm -rf /etc/vbox || log_error "Failed to remove system-wide configuration files"
  rm -rf /usr/lib/virtualbox || log_error "Failed to remove VirtualBox binaries"
  rm -rf /var/lib/virtualbox || log_error "Failed to remove VirtualBox data files"
  log_success "VirtualBox configuration and data files removed."
}

# Function to remove VirtualBox extension pack
remove_extension_pack() {
  echo "Removing VirtualBox extension pack..."
  if [ -f "/usr/lib/virtualbox/extpacks/Oracle_VM_VirtualBox_Extension_Pack.vbox-extpack" ]; then
    sudo VBoxManage extpack uninstall "Oracle VM VirtualBox Extension Pack" || log_error "Failed to remove VirtualBox extension pack"
    log_success "VirtualBox extension pack removed."
  else
    log_success "No VirtualBox extension pack found to remove."
  fi
}

# Main function to call all uninstall functions
main() {
  unregister_vms
  uninstall_virtualbox
  remove_repository
  remove_configuration_data
  remove_extension_pack

  # Final success message
  echo -e "\e[32m[INFO]\e[0m VirtualBox has been fully removed from your system."
}

# Run the main function
main
