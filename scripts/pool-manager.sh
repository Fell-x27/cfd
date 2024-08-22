#!/bin/bash

function pool-manager {    
    local OPTION_N_DESCRIPTIONS=(
        "pool-setup-wizard|pool-setup-wizard|Set up a new stake pool using a step-by-step interface."
        "stake-key-register|stake-key-register|Register pool-owner's stake key."
        "stake-key-unregister|stake-key-unregister|Unregister pool-owner's stake key."
        "pool-certificate-edit|pool-certificate-edit|Edit your stake pool certificate."
        "pool-certificate-submit|pool-certificate-submit|Submit your stake pool certificate to the blockchain."
        "pool-certificate-recall|pool-certificate-recall|Schedule retirement of the stake pool."
        "pool-keys-generate|pool-keys-generate|Generate your stake pool keys."
        "kes-keys-update|kes-keys-update|Update your KES keys."
    )
    validate-node-sync
    prepare_software "cardano-address" "issues"
    wrap-cli-command get-protocol
    CHOSEN_OPTION=${1:-""} 
    show-menu "$CHOSEN_OPTION" "${OPTION_N_DESCRIPTIONS[@]}"    
    echo "Selected action: $MENU_SELECTED_OPTION"
    $MENU_SELECTED_COMMAND
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
    else
       exit 1
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
    echo ""
    reg-stake-key
}

function stake-key-unregister {
    echo ""
    unreg-stake-key
}

function pool-certificate-edit {
    echo ""
    gen-pool-cert
}

function pool-certificate-submit {
    echo ""
    reg-pool-cert
}

function pool-certificate-recall {
    echo ""
    unreg-pool-cert
}

function pool-keys-generate {
    echo ""
    if gen-pools-keys; then
       gen-kes-keys
    fi
}

function kes-keys-update {
    echo ""
    gen-kes-keys
}


