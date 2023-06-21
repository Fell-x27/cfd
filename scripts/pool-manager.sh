#!/bin/bash

function pool-manager {
    validate-node-sync
    echo "---"
    prepare_software "cardano-address" "issues"
    echo ""
    echo "***************************************"

    AVAILABLE_ACTIONS=("pool-setup-wizard" "stake-key-register" "stake-key-unregister" "pool-certificate-edit" "pool-certificate-submit" "pool-certificate-recall" "pool-keys-generate" "kes-keys-update")


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

function pool-setup-wizard {
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
    echo "> Step 1: register your stake key on blockchain"
        reg-stake-key
    echo ""
    
    echo ""
    echo "> Step 2: generate pool keys"
        if gen-pools-keys; then
           gen-kes-keys
        fi
    echo ""
    
    echo ""
    echo "> Step 3: generate pool certificate"
        gen-pool-cert    
    echo ""
    
    echo ""
    echo "> Step 4: register pool certificate on blockchain and delegate to it"
        reg-pool-cert
    echo ""
    
}


function stake-key-register {
    reg-stake-key
}

function stake-key-unregister {
    unreg-stake-key
}

function pool-certificate-edit {
    gen-pool-cert
}

function pool-certificate-submit {
    reg-pool-cert
}

function pool-certificate-recall {
    unreg-pool-cert
}

function pool-keys-generate {
    if gen-pools-keys; then
       gen-kes-keys
    fi
}

function kes-keys-update {
    gen-kes-keys
}


