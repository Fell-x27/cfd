#!/bin/bash

function wallet-manager {
    local OPTION_N_DESCRIPTIONS=(
        "wallet-create|wallet-create|Create a new Shelley wallet for payment operations."
        "wallet-restore|wallet-restore|Restore an existent Shelley wallet with your mnemonic."
        "get-wallet-utxo|get-wallet-utxo|Check your UTXOs."
    )
    prepare_software "cardano-address" "issues"
    CHOSEN_OPTION=${1:-""} 
    show-menu "$CHOSEN_OPTION" "${OPTION_N_DESCRIPTIONS[@]}"
    
    echo "Selected action: $MENU_SELECTED_OPTION"
    $MENU_SELECTED_COMMAND
}
