#!/bin/bash


function network-manager {    
    local AVAILABLE_NETWORKS=$(from-config '.networks | keys[]')
    local NETWORKS_ARR=($AVAILABLE_NETWORKS)

    local OPTION_N_DESCRIPTIONS=()

    for NETWORK in "${NETWORKS_ARR[@]}"; do
        NETWORK_DESCRIPTION=$(from-config ".networks.\"${NETWORK}\".description")
        
        OPTION_N_DESCRIPTIONS+=("$NETWORK|$NETWORK|$NETWORK_DESCRIPTION")
    done

    CHOSEN_OPTION=${1:-""} 
    
    if [ -z "$CHOSEN_OPTION" ]; then
        echo ""
        echo "To start, you need to choose one of the available Cardano networks"
    fi
    
    show-menu "$CHOSEN_OPTION" "${OPTION_N_DESCRIPTIONS[@]}"
    
    echo "Selected network: $MENU_SELECTED_OPTION"
    NETWORK_NAME=$MENU_SELECTED_COMMAND
}
