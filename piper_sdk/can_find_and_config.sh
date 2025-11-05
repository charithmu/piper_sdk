#!/bin/bash

# Usage: ./check_and_setup_can.sh <CAN_NAME> <BITRATE> <USB_ADDRESS> <TIMEOUT>

# Default parameters
CAN_NAME="${1:-can0}"
BITRATE="${2:-1000000}"
USB_ADDRESS="${3}"
TIMEOUT="${4:-120}"  # Timeout in seconds, default 120 seconds

sudo -v

ROOT="$(dirname "$(readlink -f "$0")")"

if [ -z "$USB_ADDRESS" ]; then
    echo "Error: USB hardware address must be provided."
    exit 1
fi

# Start time
START_TIME=$(date +%s)

# Timeout flag
TIMED_OUT=false

echo "Starting check for CAN device at USB hardware address $USB_ADDRESS..."

while true; do
    # Get current time
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

    # Check if timeout reached
    if [ "$ELAPSED_TIME" -ge "$TIMEOUT" ]; then
        echo "Timeout: CAN device not found within $TIMEOUT seconds."
        TIMED_OUT=true
        break
    fi

    # Check if device is connected at specified USB hardware address
    DEVICE_FOUND=false
    for iface in $(ip -br link show type can | awk '{print $1}'); do
        BUS_INFO=$(sudo ethtool -i "$iface" | grep "bus-info" | awk '{print $2}')
        if [ "$BUS_INFO" = "$USB_ADDRESS" ]; then
            DEVICE_FOUND=true
            break
        fi
    done

    if [ "$DEVICE_FOUND" = "true" ]; then
        echo "Found CAN device, calling configuration script..."
        sudo bash $ROOT/can_activate.sh "$CAN_NAME" "$BITRATE" "$USB_ADDRESS"
        if [ $? -eq 0 ]; then
            echo "CAN device configured successfully."
            exit 0
        else
            echo "Configuration script execution failed."
            exit 1
        fi
    fi

    echo "CAN device not found, waiting and retrying..."

    # Check every 5 seconds
    sleep 5
done

# If loop ends due to timeout, output timeout message
if [ "$TIMED_OUT" = "true" ]; then
    echo "Unable to find CAN device within specified time, script exiting."
    exit 1
fi
