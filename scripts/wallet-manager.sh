#!/bin/bash

function wallet-manager {
    echo "---"
    prepare_software "cardano-address" "issues"
    echo ""
    echo "***************************************"
    AVAILABLE_ACTIONS=("wallet-create" "wallet-restore" "get-wallet-utxo")

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
