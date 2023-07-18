#!/bin/bash

source "$(dirname "$0")/scripts/runners.sh"

function run-software {    
    local OPTION_N_DESCRIPTIONS=(
        "node-relay|run_cardano_node|Run passive cardano node ${UNDERLINE}V%cardano-node%${NORMAL}" 
        "node-relay-local|run_cardano_node --noip|Run passive cardano node ${UNDERLINE}V%cardano-node%${NORMAL} with omitted IP"
        "node-block-producer|run_cardano_pool|Run cardano node ${UNDERLINE}V%cardano-node%${NORMAL} as a block producer"
        "db-sync|run_cardano_db_sync|Run cardano db-sync ${UNDERLINE}V%cardano-db-sync%${NORMAL} (postgres setup wizard included!)" 
        "submit-api|run_cardano_sapi|Run cardano submit API server"
        "wallet|run_cardano_wallet|Run cardano wallet ${UNDERLINE}%cardano-wallet%${NORMAL} backend"
    )
    
    for index in "${!OPTION_N_DESCRIPTIONS[@]}"; do
        local element="${OPTION_N_DESCRIPTIONS[$index]}"
        while [[ $element = *%* ]]; do
            local before=${element%%\%*}  # Everything before the first %
            local temp=${element#*\%}  # Remove everything before the first %
            local key=${temp%%\%*}  # Everything before the next % (i.e. between the %)
            local after=${temp#*\%}  # Everything after the next % 
            local software_version=$(get-sf-version "$key")
            element="$before$software_version$after"  # Replace %key% with the software_version
        done
        OPTION_N_DESCRIPTIONS[$index]="$element"
    done   
    
    CHOSEN_OPTION=${1:-""} 
    show-menu "$CHOSEN_OPTION" "${OPTION_N_DESCRIPTIONS[@]}"
    
    echo "Selected software: $MENU_SELECTED_OPTION"
    $MENU_SELECTED_COMMAND
}




