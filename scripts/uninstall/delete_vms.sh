#!/bin/bash

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
            echo "VM '$VM_NAME' deleted successfully."
        else
            echo "Failed to delete VM '$VM_NAME'."
        fi
    else
        echo "VM '$VM_NAME' does not exist or is not registered."
    fi
}

# Main function to process multiple VMs
main() {
    # Check if at least one VM name is provided
    if [ "$#" -lt 1 ]; then
        echo "Usage: $0 <vm_name_1> <vm_name_2> ... <vm_name_N>"
        exit 1
    fi
    
    # Loop through each VM name passed as argument
    for vm_name in "$@"; do
        delete_vm "$vm_name"
    done

    echo "All specified VMs have been processed."
}

# Run the main function with the script arguments
main "$@"
