#!/bin/bash

source "$(dirname "$0")/scripts/runners.sh"

function run-software {
    echo ""
    echo "***************************************"

    local KEYS=(${!RUNNERS[@]})
    local SORTED_KEYS=($(for key in "${KEYS[@]}"; do echo "$key"; done | sort))
    local RUNNER SOFTWARE INNER_ARRAY

    if [ -z "$1" ]; then
        echo "Choose the software to run:"
        COUNTER=1
        for KEY in "${SORTED_KEYS[@]}"; do
        
            INNER_ARRAY="${RUNNERS[$KEY]}"            
                
            RUNNER=$(echo "${INNER_ARRAY}" | cut -d'|' -f1)
            SOFTWARE=$(echo "${INNER_ARRAY}" | cut -d'|' -f2)
        
            echo "$COUNTER: $KEY ($(get-sf-version ${SOFTWARE}))"
            COUNTER=$((COUNTER+1))
        done

        read -p "Enter the number of the desired option: " SELECTED_OPTION
        SELECTED_OPTION=$((SELECTED_OPTION-1))
    else
        SELECTED_OPTION=-1
        for i in "${!SORTED_KEYS[@]}"; do
           if [[ "${SORTED_KEYS[$i]}" = "$1" ]]; then
               SELECTED_OPTION=$i
           fi
        done
        if [ $SELECTED_OPTION -eq -1 ]; then
            if [ -z "$1" ]; then
                echo "No software selected. Exiting."
            else
                echo "Unknown software: $1. Exiting."
            fi
            exit 1
        fi
    fi

    SELECTED_KEY=${SORTED_KEYS[$SELECTED_OPTION]}

    if [ -z "$SELECTED_KEY" ]; then
        echo "No software selected. Exiting."
        exit 1
    fi
    
    echo "Selected option: $SELECTED_KEY"
    
    INNER_ARRAY=(${RUNNERS[$SELECTED_KEY]})
    RUNNER=$(echo "${INNER_ARRAY}" | cut -d'|' -f1)
    ${RUNNER}
}

