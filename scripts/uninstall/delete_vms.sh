#!/bin/bash

# Function to log success messages
log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to log error messages
log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Function to check if a VM exists
check_vm_exists() {
    VM_NAME="$1"
    
    # Check if the VM exists using VBoxManage
    VBoxManage showvminfo "$VM_NAME" &>/dev/null
    if [ $? -eq 0 ]; then
        return 0  # VM exists
    else
        return 1  # VM does not exist
    fi
}

# Function to delete a VM
delete_vm() {
    VM_NAME="$1"
    
    # Check if the VM exists
    if check_vm_exists "$VM_NAME"; then
        echo "Attempting to delete VM: $VM_NAME"
        
        # Unregister and delete the VM
        VBoxManage unregistervm "$VM_NAME" --delete
        if [ $? -eq 0 ]; then
            log_success "VM '$VM_NAME' deleted successfully."
        else
            log_error "Failed to delete VM '$VM_NAME'."
        fi
    else
        log_error "VM '$VM_NAME' does not exist or is not registered."
    fi
}

# Function to ask for confirmation for deleting all VMs (including master) or just nodes
confirm_deletion() {
    ACTION="$1"
    
    if [ "$ACTION" == "all" ]; then
        echo -n "Are you sure you want to delete all VMs including the master? [y/n]: "
    elif [ "$ACTION" == "nodes" ]; then
        echo -n "Are you sure you want to delete all node VMs? [y/n]: "
    fi
    
    read -r confirmation
    if [[ "$confirmation" != "y" && "$confirmation" != "yes" ]]; then
        log_error "Deletion aborted."
        exit 1
    fi
}

# Function to delete all VMs (including master)
delete_all_vms() {
    confirm_deletion "all"
    vboxmanage list vms | awk -F '"' '{print $2}' | while read vm_name; do
        delete_vm "$vm_name"
    done
}

# Function to delete only node VMs
delete_node_vms() {
    confirm_deletion "nodes"
    vboxmanage list vms | grep -E 'node_' | awk -F '"' '{print $2}' | while read vm_name; do
        delete_vm "$vm_name"
    done
}

# Main function to process deletion based on the action parameter
main() {
    # Check if the user specified an action (all or nodes)
    if [ "$#" -lt 1 ]; then
        log_error "Usage: $0 <all|nodes>"
        exit 1
    fi

    ACTION="$1"
    
    case "$ACTION" in
        "all")
            # Delete all VMs including the master
            delete_all_vms
            ;;
        "nodes")
            # Delete only node VMs
            delete_node_vms
            ;;
        *)
            log_error "Invalid action specified. Use 'all' or 'nodes'."
            exit 1
            ;;
    esac

    log_success "Process completed."
}

# Run the main function with the script arguments
main "$@"
