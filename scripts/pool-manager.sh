#!/bin/bash

source "$(dirname "$0")/scripts/pool-tools.sh"

function pool-manager {
    wrap-cli-command run-check-sync "silent"
    SYNC_STATE=$(run-check-sync)    
    SYNC_STATE=$(echo "$SYNC_STATE" | jq -r '.syncProgress')
    
    
    if (( $(echo "$SYNC_STATE < 100" | bc -l) )); then
        echo -e "\033[43m\033[30mWARNING\033[0m: The node is not synced yet, please wait."
        echo "Current sync level: $SYNC_STATE%"
        exit
    fi
    
    echo "---"
    prepare_software "cardano-address" "issues"
    echo ""
    echo "***************************************"


    AVAILABLE_ACTIONS=("init-pool" "certificate-update" "certificate-submit" "kes-update")

    if [ ! -z "$1" ] && [[ " ${AVAILABLE_ACTIONS[@]} " =~ " $1 " ]]; then
        ACTION_NAME="$1"
    else
        if [ ! -z "$1" ] && [[ ! " ${AVAILABLE_ACTIONS[@]} " =~ " $1 " ]]; then
            echo "Unknown action."
        else
            echo "Action not selected."
        fi

        echo "Available actions:"

        COUNTER=1
        for ACTION in "${AVAILABLE_ACTIONS[@]}"; do
            echo "$COUNTER. $ACTION"
            ((COUNTER++))
        done

        echo -n "Enter the number corresponding to the desired action:"
        read SELECTED_NUM

        if [[ $SELECTED_NUM -ge 1 ]] && [[ $SELECTED_NUM -le ${#AVAILABLE_ACTIONS[@]} ]]; then
            ACTION_NAME="${AVAILABLE_ACTIONS[SELECTED_NUM-1]}"
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi

    echo "Selected action: $ACTION_NAME"
    $ACTION_NAME
}

function init-pool {
    echo ""
    echo "Step 1: register your stake key on blockchain"
    register-stake-key
    echo ""
    
    echo ""
    echo "Step 2: generate pool keys"
    if gen-pools-keys; then
       gen-kes-keys
    fi
    echo ""
    
    echo ""
    echo "Step 3: generate pool certificate"
    gen-pool-cert    
    echo ""
    
    echo ""
    echo "Step 4: register pool certificate on blockchain and delegate to it"
    reg-pool-cert
    echo ""
    
}

function certificate-update {
    gen-pool-cert
}

function certificate-submit {
    reg-pool-cert
}

function kes-update {
    gen-kes-keys
}


