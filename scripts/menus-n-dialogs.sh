#!/bin/bash

MENU_SELECTED_OPTION=""
MENU_SELECTED_COMMAND=""
MENU_SELECTED_DESCRIPTION=""
DIRECT_CALL="$0"

function show-menu {    
    echo "***************************************"
    CHOSEN_OPTION=$1
    shift 1

    local OPTION_N_DESCRIPTIONS=("$@")
    
    local OPTION_NAMES=()
    local OPTION_COMMANDS=()
    local DESCRIPTIONS=()

    for line in "${OPTION_N_DESCRIPTIONS[@]}"; do
        IFS='|' read -r -a split <<< "$line"
        OPTION_NAMES+=("${split[0]}")
        OPTION_COMMANDS+=("${split[1]}")
        DESCRIPTIONS+=("${split[2]}")
    done

    max_len=0
    for option in "${OPTION_NAMES[@]}"; do
        clean_option=$(printf "$option" | sed 's/\x1b\[[0-9;]*m//g')
        len=${#clean_option}
        if (( len > max_len )); then
            max_len=$len
        fi
    done
    ((max_len+=3))

    if [[ -z "$CHOSEN_OPTION" || ! " ${OPTION_NAMES[@]} " =~ " ${CHOSEN_OPTION} " ]]; then
        if [ -z "$CHOSEN_OPTION" ]; then
            echo "Please, select an option:"
        else
            echo "Unknown option: $CHOSEN_OPTION"
        fi

        for index in "${!OPTION_NAMES[@]}"; do
            if [ -z "${DESCRIPTIONS[$index]}" ]; then
                printf "%d. %-*s" $((index+1)) $max_len "${OPTION_NAMES[$index]}"
                echo
            else
                printf "%d. %-*s" $((index+1)) $max_len "${OPTION_NAMES[$index]}"
                echo -e " - ${DESCRIPTIONS[$index]}"
            fi
        done

        printf "Enter the number corresponding to the desired option: "
        read user_input

        if [[ $user_input =~ ^[0-9]+$ ]] && [ $user_input -le ${#OPTION_NAMES[@]} ]; then
            CHOSEN_OPTION=${OPTION_NAMES[$((user_input-1))]}
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi

    CHOSEN_OPTION_INDEX=-1
    for index in "${!OPTION_NAMES[@]}"; do
        if [ "${OPTION_NAMES[$index]}" == "$CHOSEN_OPTION" ]; then
            CHOSEN_OPTION_INDEX=$index
            break
        fi
    done    
    MENU_SELECTED_COMMAND="${OPTION_COMMANDS[$CHOSEN_OPTION_INDEX]}"
    MENU_SELECTED_DESCRIPTION="${DESCRIPTIONS[$CHOSEN_OPTION_INDEX]}"
    MENU_SELECTED_OPTION="$CHOSEN_OPTION"
    DIRECT_CALL="$DIRECT_CALL $CHOSEN_OPTION"
}

function are-you-sure-dialog {
    local MESSAGE=${1:-"Are you sure you want to proceed?"}
    local DEFAULT_VALUE=${2:-"n"}

    echo -ne "$MESSAGE [Default: $DEFAULT_VALUE]" 
    read -p " (y/n) " -r REPLY

    if [[ -z $REPLY ]]; then
        REPLY=$DEFAULT_VALUE
    fi

    if [[ $REPLY =~ ^[Yy](es)?$ ]]
    then
        return 0
    else
        return 1
    fi
}


function rewriting-prompt {
    if [[ -f "$1" ]]; then
        local WARNING_MESSAGE="${BOLD}${WHITE_ON_RED}Warning!${NORMAL} $2 Are you sure?"
        if are-you-sure-dialog "$WARNING_MESSAGE"; then
            return 0
        else
            echo "Operation canceled."
            return 1
        fi
    fi
}




