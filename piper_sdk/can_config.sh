#!/bin/bash

# Usage Instructions:

# 1. Prerequisites
#     The system must have ip and ethtool tools installed.
#     sudo apt install ethtool can-utils
#     Ensure the gs_usb driver is correctly installed.

# 2. Background
#  This script is designed to automatically manage, rename, and activate CAN (Controller Area Network) interfaces.
#  It checks the current number of CAN modules in the system and renames/activates CAN interfaces based on predefined USB ports.
#  This is particularly useful for systems with multiple CAN modules that require specific naming.

# 3. Main Features
#  Check CAN module count: Ensures the detected number of CAN modules matches the expected count.
#  Get USB port information: Uses ethtool to retrieve USB port information for each CAN module.
#  Verify USB ports: Checks if each CAN module's USB port matches the predefined port list.
#  Rename CAN interfaces: Renames CAN interfaces to target names based on predefined USB ports.

# 4. Script Configuration
#   Key configuration items include expected CAN module count, default CAN interface name, and bitrate settings:
#   1. Expected CAN module count:
#     EXPECTED_CAN_COUNT=1
#     This value determines how many CAN modules should be detected in the system.
#   2. Default CAN interface name for single module:
#     DEFAULT_CAN_NAME="${1:-can0}"
#     The default CAN interface name can be specified via command-line parameter, defaults to can0.
#   3. Default bitrate for single CAN module:
#     DEFAULT_BITRATE="${2:-500000}"
#     The bitrate for a single CAN module can be specified via command-line parameter, defaults to 500000.
#   4. Configuration for multiple CAN modules:
#     declare -A USB_PORTS
#     USB_PORTS["1-2:1.0"]="can_device_1:500000"
#     USB_PORTS["1-3:1.0"]="can_device_2:250000"
#     Keys represent USB ports, values are interface names and bitrates separated by colon.

# 5. Usage Steps
#  1. Edit the script:
#   1. Modify predefined values:
#      - Expected CAN module count: EXPECTED_CAN_COUNT=2, can be modified to match the number of CAN modules
#      - For single CAN module, skip this section after setting the above parameters
#      - For multiple CAN modules, define USB ports and target interface names:
#          First, insert a CAN module into the expected USB port (insert one module at a time during initial setup)
#          Then execute: sudo ethtool -i can0 | grep bus, and record the parameter after bus-info:
#          Next, insert another CAN module (must be a different USB port), and repeat the previous step
#          (You can use the same CAN module for different USB ports, as modules are distinguished by USB address)
#          After all modules are assigned to their USB ports and recorded,
#          modify the USB ports (bus-info) and target interface names according to actual situation.
#          can_device_1:500000, first part is the CAN name, second part is the bitrate
#            declare -A USB_PORTS
#            USB_PORTS["1-2:1.0"]="can_device_1:500000"
#            USB_PORTS["1-3:1.0"]="can_device_2:250000"
#          Modify the content inside USB_PORTS["1-3:1.0"] double quotes to the recorded bus-info parameter
#   2. Grant script execution permission:
#       Open terminal, navigate to script directory, execute:
#       chmod +x can_config.sh
#   3. Run the script:
#     Use sudo to execute the script, as administrator privileges are required to modify network interfaces:
#       1. Single CAN module
#         1. Specify default CAN interface name and bitrate via command-line (defaults to can0 and 500000):
#           sudo bash ./can_config.sh [CAN_interface_name] [bitrate]
#           For example, specify interface name as my_can_interface, bitrate as 1000000:
#           sudo bash ./can_config.sh my_can_interface 1000000
#         2. Specify CAN name by USB hardware address:
#           sudo bash ./can_config.sh [CAN_interface_name] [bitrate] [USB_hardware_address]
#           For example, interface name my_can_interface, bitrate 1000000, USB address 1-3:1.0:
#           sudo bash ./can_config.sh my_can_interface 1000000 1-3:1.0
#           This assigns the CAN device at USB address 1-3:1.0 the name my_can_interface with bitrate 1000000
#       2. Multiple CAN modules
#         For multiple CAN modules, set the USB_PORTS array in the script to specify interface names and bitrates.
#         No additional parameters needed, run directly:
#         sudo ./can_config.sh

# Important Notes

#     Permission requirements:
#         The script requires sudo privileges as network interface renaming and configuration need administrator permissions.
#         Ensure you have sufficient permissions to run this script.

#     Script environment:
#         This script is designed to run in bash environment. Ensure your system uses bash, not other shells (like sh).
#         You can verify by checking the script's Shebang line (#!/bin/bash).

#     USB port information:
#         Ensure your predefined USB port information (bus-info) matches the actual ethtool output from the system.
#         Use commands like: sudo ethtool -i can0, sudo ethtool -i can1 to check each CAN interface's bus-info.

#     Interface conflicts:
#         Ensure target interface names (like can_device_1, can_device_2) are unique and don't conflict with existing interface names.
#         To modify USB port and interface name mappings, adjust the USB_PORTS array according to actual situation.
#-------------------------------------------------------------------------------------------------#

# Expected CAN module count
EXPECTED_CAN_COUNT=1

if [ "$EXPECTED_CAN_COUNT" -eq 1 ]; then
    # Default CAN name, can be set by user via command-line parameter
    DEFAULT_CAN_NAME="${1:-can0}"

    # Default bitrate for single CAN module, can be set by user via command-line parameter
    DEFAULT_BITRATE="${2:-1000000}"

    # USB hardware address (optional parameter)
    USB_ADDRESS="${3}"
fi

# Predefined USB ports, target interface names and bitrates (used for multiple CAN modules)
if [ "$EXPECTED_CAN_COUNT" -ne 1 ]; then
    declare -A USB_PORTS 
    USB_PORTS["1-2:1.0"]="can_left:1000000"
    USB_PORTS["1-4:1.0"]="can_right:1000000"
fi

# Get current number of CAN modules in the system
CURRENT_CAN_COUNT=$(ip link show type can | grep -c "link/can")

# Check if current CAN module count matches expectation
if [ "$CURRENT_CAN_COUNT" -ne "$EXPECTED_CAN_COUNT" ]; then
    echo "Error: Detected CAN module count ($CURRENT_CAN_COUNT) does not match expected count ($EXPECTED_CAN_COUNT)."
    exit 1
fi

# Load gs_usb module
sudo modprobe gs_usb
if [ $? -ne 0 ]; then
    echo "Error: Unable to load gs_usb module."
    exit 1
fi

# Check if only one CAN module needs to be processed
if [ "$EXPECTED_CAN_COUNT" -eq 1 ]; then
    if [ -n "$USB_ADDRESS" ]; then
        echo "Detected USB hardware address parameter: $USB_ADDRESS"
        
        # Use ethtool to find CAN interface corresponding to USB hardware address
        INTERFACE_NAME=""
        for iface in $(ip -br link show type can | awk '{print $1}'); do
            BUS_INFO=$(sudo ethtool -i "$iface" | grep "bus-info" | awk '{print $2}')
            if [ "$BUS_INFO" = "$USB_ADDRESS" ]; then
                INTERFACE_NAME="$iface"
                break
            fi
        done
        
        if [ -z "$INTERFACE_NAME" ]; then
            echo "Error: Unable to find CAN interface corresponding to USB hardware address $USB_ADDRESS."
            exit 1
        else
            echo "Found interface corresponding to USB hardware address $USB_ADDRESS: $INTERFACE_NAME"
        fi
    else
        # Get the unique CAN interface
        INTERFACE_NAME=$(ip -br link show type can | awk '{print $1}')
        
        # Check if interface name was retrieved
        if [ -z "$INTERFACE_NAME" ]; then
            echo "Error: Unable to detect CAN interface."
            exit 1
        fi

        echo "Expected only one CAN module, detected interface $INTERFACE_NAME"
    fi

    # Check if current interface is already activated
    IS_LINK_UP=$(ip link show "$INTERFACE_NAME" | grep -q "UP" && echo "yes" || echo "no")

    # Get current interface bitrate
    CURRENT_BITRATE=$(ip -details link show "$INTERFACE_NAME" | grep -oP 'bitrate \K\d+')

    if [ "$IS_LINK_UP" = "yes" ] && [ "$CURRENT_BITRATE" -eq "$DEFAULT_BITRATE" ]; then
        echo "Interface $INTERFACE_NAME is already activated with bitrate $DEFAULT_BITRATE"
        
        # Check if interface name matches default name
        if [ "$INTERFACE_NAME" != "$DEFAULT_CAN_NAME" ]; then
            echo "Renaming interface $INTERFACE_NAME to $DEFAULT_CAN_NAME"
            sudo ip link set "$INTERFACE_NAME" down
            sudo ip link set "$INTERFACE_NAME" name "$DEFAULT_CAN_NAME"
            sudo ip link set "$DEFAULT_CAN_NAME" up
            echo "Interface has been renamed to $DEFAULT_CAN_NAME and reactivated."
        else
            echo "Interface name is already $DEFAULT_CAN_NAME"
        fi
    else
        # If interface is not activated or bitrate differs, configure it
        if [ "$IS_LINK_UP" = "yes" ]; then
            echo "Interface $INTERFACE_NAME is already activated, but bitrate is $CURRENT_BITRATE, which does not match the set value of $DEFAULT_BITRATE."
        else
            echo "Interface $INTERFACE_NAME is not activated or bitrate is not set."
        fi
        
        # Set interface bitrate and activate
        sudo ip link set "$INTERFACE_NAME" down
        sudo ip link set "$INTERFACE_NAME" type can bitrate $DEFAULT_BITRATE
        sudo ip link set "$INTERFACE_NAME" up
        echo "Interface $INTERFACE_NAME has been reset to bitrate $DEFAULT_BITRATE and activated."
        
        # Rename interface to default name
        if [ "$INTERFACE_NAME" != "$DEFAULT_CAN_NAME" ]; then
            echo "Renaming interface $INTERFACE_NAME to $DEFAULT_CAN_NAME"
            sudo ip link set "$INTERFACE_NAME" down
            sudo ip link set "$INTERFACE_NAME" name "$DEFAULT_CAN_NAME"
            sudo ip link set "$DEFAULT_CAN_NAME" up
            echo "Interface has been renamed to $DEFAULT_CAN_NAME and reactivated."
        fi
    fi
else
    # Handle multiple CAN modules

    # Check if USB port and target interface name count matches expected CAN module count
    PREDEFINED_COUNT=${#USB_PORTS[@]}
    if [ "$EXPECTED_CAN_COUNT" -ne "$PREDEFINED_COUNT" ]; then
        echo "Error: Expected CAN module count ($EXPECTED_CAN_COUNT) does not match predefined USB port count ($PREDEFINED_COUNT)."
        exit 1
    fi

    # Iterate through all CAN interfaces
    for iface in $(ip -br link show type can | awk '{print $1}'); do
        # Use ethtool to get bus-info
        BUS_INFO=$(sudo ethtool -i "$iface" | grep "bus-info" | awk '{print $2}')
        
        if [ -z "$BUS_INFO" ];then
            echo "Error: Unable to get bus-info for interface $iface."
            continue
        fi
        
        echo "Interface $iface is connected to USB port $BUS_INFO"

        # Check if bus-info is in predefined USB port list
        if [ -n "${USB_PORTS[$BUS_INFO]}" ];then
            IFS=':' read -r TARGET_NAME TARGET_BITRATE <<< "${USB_PORTS[$BUS_INFO]}"
            
            # Check if current interface is activated
            IS_LINK_UP=$(ip link show "$iface" | grep -q "UP" && echo "yes" || echo "no")

            # Get current interface bitrate
            CURRENT_BITRATE=$(ip -details link show "$iface" | grep -oP 'bitrate \K\d+')

            if [ "$IS_LINK_UP" = "yes" ] && [ "$CURRENT_BITRATE" -eq "$TARGET_BITRATE" ]; then
                echo "Interface $iface is already activated with bitrate $TARGET_BITRATE"
                
                # Check if interface name matches target name
                if [ "$iface" != "$TARGET_NAME" ]; then
                    echo "Renaming interface $iface to $TARGET_NAME"
                    sudo ip link set "$iface" down
                    sudo ip link set "$iface" name "$TARGET_NAME"
                    sudo ip link set "$TARGET_NAME" up
                    echo "Interface has been renamed to $TARGET_NAME and reactivated."
                else
                    echo "Interface name is already $TARGET_NAME"
                fi
            else
                # If interface is not activated or bitrate differs, configure it
                if [ "$IS_LINK_UP" = "yes" ]; then
                    echo "Interface $iface is already activated, but bitrate is $CURRENT_BITRATE, which does not match the set value of $TARGET_BITRATE."
                else
                    echo "Interface $iface is not activated or bitrate is not set."
                fi
                
                # Set interface bitrate and activate
                sudo ip link set "$iface" down
                sudo ip link set "$iface" type can bitrate $TARGET_BITRATE
                sudo ip link set "$iface" up
                echo "Interface $iface has been reset to bitrate $TARGET_BITRATE and activated."
                
                # Rename interface to target name
                if [ "$iface" != "$TARGET_NAME" ]; then
                    echo "Renaming interface $iface to $TARGET_NAME"
                    sudo ip link set "$iface" down
                    sudo ip link set "$iface" name "$TARGET_NAME"
                    sudo ip link set "$TARGET_NAME" up
                    echo "Interface has been renamed to $TARGET_NAME and reactivated."
                fi
            fi
        else
            echo "Error: Unknown USB port $BUS_INFO corresponding to interface $iface."
            exit 1
        fi
    done
fi

echo "All CAN interfaces have been successfully renamed and activated."
