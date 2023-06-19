#!/bin/bash

source "$(dirname "$0")/scripts/runners.sh"

function run-software {
    echo ""
    echo "***************************************"

    keys=(${!runners[@]})
    sorted_keys=($(for key in "${keys[@]}"; do echo "$key"; done | sort))

    if [ -z "$1" ]; then
        echo "Choose the action:"
        counter=1
        for key in "${sorted_keys[@]}"; do
            echo "$counter: $key"
            counter=$((counter+1))
        done

        read -p "Enter the number of the desired option: " selected_option
        selected_option=$((selected_option-1))
    else
        selected_option=-1
        for i in "${!sorted_keys[@]}"; do
           if [[ "${sorted_keys[$i]}" = "$1" ]]; then
               selected_option=$i
           fi
        done
        if [ $selected_option -eq -1 ]; then
            if [ -z "$1" ]; then
                echo "No action selected. Exiting."
            else
                echo "Unknown action: $1. Exiting."
            fi
            exit 1
        fi
    fi

    selected_key=${sorted_keys[$selected_option]}

    if [ -z "$selected_key" ]; then
        echo "No action selected. Exiting."
        exit 1
    fi
    
    echo "Selected option: $selected_key"
    ${runners[$selected_key]}
}

