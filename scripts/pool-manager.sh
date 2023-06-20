#!/bin/bash

source "$(dirname "$0")/scripts/pool-tools.sh"

function pool-manager {
    wrap-cli-command run-check-sync "silent"
    SYNC_STATE=$(run-check-sync)    
    SYNC_STATE=$(echo "$SYNC_STATE" | jq -r '.syncProgress')
    
    
    if (( $(echo "$SYNC_STATE < 100" | bc -l) )); then
        echo -e "${BOLD}${BLACK_ON_YELLOW}WARNING${NORMAL}: The node is not synced yet, please wait."
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
    local POOL_REG_COST=$(jq -r ".stakePoolDeposit" $CARDANO_CONFIG_DIR/protocol.json)
    local STAKE_REG_COST=$(jq -r ".stakeAddressDeposit" $CARDANO_CONFIG_DIR/protocol.json)

    echo -e "${BOLD}${BLACK_ON_YELLOW} ATTENTION! ${NORMAL}"
    echo -e "Registering a stake key requires a${BOLD}${BLACK_ON_LIGHT_GRAY} returnable deposit of $(expr $STAKE_REG_COST / 1000000) ADA ${NORMAL}."
    echo -e "Registering a pool requires a${BOLD}${BLACK_ON_LIGHT_GRAY} returnable deposit of $(expr $POOL_REG_COST / 1000000) ADA ${NORMAL}."
    echo "Subsequent updates are free of charge, except for the transaction fee."

    local CONTINUE
    read -p "Continue?(y/n): " CONTINUE
    CONTINUE=$(echo "$CONTINUE" | tr '[:upper:]' '[:lower:]')

    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "yes" ] ; then
        echo "Exiting."
        exit 1
    fi

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


