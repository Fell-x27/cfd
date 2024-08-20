#!/bin/bash

function keyring-manager {
    local OPTION_N_DESCRIPTIONS=(
        "list-keys|list-keys|Show the list of managed keys."
        "reveal-keys|reveal-keys|Reveal the managed keys."
        "hide-keys|hide-keys|Hide the managed keys."
        "export-keys|export-keys|Export the managed keys."
    )

    CHOSEN_OPTION=${1:-""}
    show-menu "$CHOSEN_OPTION" "${OPTION_N_DESCRIPTIONS[@]}"

    echo "Selected action: $MENU_SELECTED_OPTION"
    $MENU_SELECTED_COMMAND
}

function list-keys {
    echo "LIST"
}

function reveal-keys {
    echo "REVEAL"
}

function hide-keys {
    echo "HIDE"
}

function export-keys {
    echo "EXPORT"
}
