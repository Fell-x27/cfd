#!/bin/bash

function install-software {    
    local OPTION_N_DESCRIPTIONS=(
        "node|prepare_software 'cardano-node'|Install cardano-node and cardano submit-api ${UNDERLINE}V%cardano-node%${NORMAL}" 
        "db-sync|prepare_software 'cardano-db-sync'|Install cardano db-sync ${UNDERLINE}V%cardano-db-sync%${NORMAL}" 
        "wallet|prepare_software cardano-wallet|Install cardano-wallet ${UNDERLINE}%cardano-wallet%${NORMAL} backend"
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
    $MENU_SELECTED_COMMAND "${@:2}"
}




