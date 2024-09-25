#!/bin/bash

function install-software {    
    local OPTION_N_DESCRIPTIONS=(
        "cardano-node|prepare_software 'cardano-node'|Install cardano-node and cardano submit-api ${UNDERLINE}V%cardano-node%${NORMAL}" 
        "cardano-db-sync|prepare_software 'cardano-db-sync'|Install cardano db-sync ${UNDERLINE}V%cardano-db-sync%${NORMAL}" 
        "cardano-wallet|prepare_software cardano-wallet|Install cardano-wallet ${UNDERLINE}%cardano-wallet%${NORMAL} backend"
        "cardano-address|prepare_software cardano-address|Install cardano-address ${UNDERLINE}%cardano-address%${NORMAL} tool"
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
    
    echo "Selected software: $MENU_SELECTED_OPTION" 1>&2
    $MENU_SELECTED_COMMAND "${@:2}"
}




