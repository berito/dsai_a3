#!/bin/bash

# Function to display success messages
log_success() {
  echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Step 1: Update and Install Required Packages
update_and_install_prerequisites() {
  echo "Updating and installing required packages..."
  sudo apt update || { echo "Failed to update package lists"; exit 1; }
  sudo apt install -y software-properties-common wget || { echo "Failed to install prerequisites"; exit 1; }
  log_success "Required packages installed."
}

# Step 2: Add VirtualBox Repository and Install VirtualBox
add_virtualbox_repo() {
  echo "Adding VirtualBox repository..."
  sudo add-apt-repository -y "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" || { echo "Failed to add repository"; exit 1; }
  wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add - || { echo "Failed to add repository key"; exit 1; }
  log_success "VirtualBox repository added."
}

# Step 3: Install the Latest Version of VirtualBox
install_virtualbox() {
  echo "Installing VirtualBox..."
  sudo apt update || { echo "Failed to update repository"; exit 1; }
  sudo apt install -y virtualbox-7.0 || { echo "Failed to install VirtualBox"; exit 1; }
  log_success "VirtualBox installed."
}

# Step 4: Install VirtualBox Extension Pack
install_extension_pack() {
  echo "Downloading VirtualBox Extension Pack..."
  wget https://download.virtualbox.org/virtualbox/7.0.14/Oracle_VM_VirtualBox_Extension_Pack-7.0.14.vbox-extpack || { echo "Failed to download Extension Pack"; exit 1; }

  echo "Installing VirtualBox Extension Pack..."
  sudo VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-7.0.14.vbox-extpack || { echo "Failed to install Extension Pack"; exit 1; }
  log_success "VirtualBox Extension Pack installed."
}

# Step 5: Verify Installation
verify_virtualbox_installation() {
  echo "Verifying VirtualBox installation..."
  vboxmanage --version || { echo "VirtualBox installation verification failed"; exit 1; }
  log_success "VirtualBox installation verified."
}

# Main Script Execution
update_and_install_prerequisites
add_virtualbox_repo
install_virtualbox
install_extension_pack
verify_virtualbox_installation

# Final Success Message
echo -e "\e[32mAll steps completed successfully! VirtualBox is installed and configured.\e[0m"
