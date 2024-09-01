#!/bin/bash

source "$(dirname "$0")/scripts/startup.sh"

function init-cfd {
    local OPTION_N_DESCRIPTIONS=(
        "install-software|install-software|Display menu with available Cardano software for installation only."
        "run-software|run-software|Display menu with available Cardano software."
        "check-sync|check-sync|Check the sync state of an already launched node."
        "wallet-manager|wallet-manager|Display menu for wallet related actions."
        "pool-manager|pool-manager|Display menu for pool related actions."
        "database-manager|database-manager|Display menu for actions related to the db-sync database."
        "keyring-manager|keyring-manager|Manage and secure your private keys."
        "cli|cli|An enhanced cardano-cli wrapper that automatically handles network-magic and socket-path issues."
    )

    CHOSEN_OPTION=${1:-""} 
    show-menu "$CHOSEN_OPTION" "${OPTION_N_DESCRIPTIONS[@]}"
    echo "Selected mode: $MENU_SELECTED_OPTION"

    source "$(dirname "$0")/scripts/${MENU_SELECTED_COMMAND}.sh"
    "${MENU_SELECTED_COMMAND}" "${@:2}"
}

init-cfd ${@:2}
DIRECT_CALL=($DIRECT_CALL)

if [ "$#" -gt "${#DIRECT_CALL[@]}" ]; then
    DIRECT_CALL="$0 $@"
else
    DIRECT_CALL="${DIRECT_CALL[@]}"
fi

echo "---"
echo -e "${UNDERLINE}Direct call for this action${NORMAL}: $DIRECT_CALL"

