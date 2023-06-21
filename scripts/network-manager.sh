#!/bin/bash

function network-manager {
    local AVAILABLE_NETWORKS=$(from-config '.networks | keys[]')
    local NETWORKS_ARR=($AVAILABLE_NETWORKS)
    local COUNTER SELECTED_NUM
    
    if [ ! -z "$1" ] && [[ " ${NETWORKS_ARR[@]} " =~ " $1 " ]]; then
        NETWORK_NAME="$1"
    else
        echo "Available networks:"

        COUNTER=1
        for NETWORK in "${NETWORKS_ARR[@]}"; do
            NETWORK_DESCRIPTION=$(from-config ".networks.\"${NETWORK}\".description") 
            echo "$COUNTER. $NETWORK [${NETWORK_DESCRIPTION}]"
            ((COUNTER++))
        done

        echo -n "Enter the number corresponding to the desired network:"
        read SELECTED_NUM

        if [[ $SELECTED_NUM -ge 1 ]] && [[ $SELECTED_NUM -le ${#NETWORKS_ARR[@]} ]]; then
            NETWORK_NAME="${NETWORKS_ARR[SELECTED_NUM-1]}"
        else
            if [ ! -z "$1" ] && [[ ! " ${NETWORKS_ARR[@]} " =~ " $1 " ]]; then
                echo "Unknown network."
            else
                echo "Network not selected."
            fi
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi
    echo ""
    echo "***************************************"
    echo "Selected network: $NETWORK_NAME"		
}
