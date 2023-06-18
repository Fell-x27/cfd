#!/bin/bash

# Including the startup script
source "$(dirname "$0")/scripts/startup.sh"

if [ ! -f "../$0" ]; then
    ln -fns $(readlink -f "$0") "../$0"
    chmod +x "../$0"
fi

echo ""
echo "***************************************"

# An array to store the names of available modes
AVAILABLE_MODES=("run-software" "check-sync" "wallet-manager" "pool-manager" "database-manager" "cli")

if [ ! -z "$2" ] && [[ " ${AVAILABLE_MODES[@]} " =~ " $2 " ]]; then
    MODE_NAME="$2"
else
    if [ ! -z "$2" ] && [[ ! " ${AVAILABLE_MODES[@]} " =~ " $2 " ]]; then
        echo "Unknown mode."
    else
        echo "Mode not selected."
    fi

    echo "Available modes:"

    COUNTER=1
    for MODE in "${AVAILABLE_MODES[@]}"; do
        echo "$COUNTER. $MODE"
        ((COUNTER++))
    done

    echo -n "Enter the number corresponding to the desired mode:"
    read SELECTED_NUM

    if [[ $SELECTED_NUM -ge 1 ]] && [[ $SELECTED_NUM -le ${#AVAILABLE_MODES[@]} ]]; then
        MODE_NAME="${AVAILABLE_MODES[SELECTED_NUM-1]}"
    else
        echo "Invalid selection. Exiting."
        exit 1
    fi
fi

echo "Selected mode: $MODE_NAME"
# Pass the rest of the arguments to the chosen mode
source "$(dirname "$0")/scripts/${MODE_NAME}.sh"
"${MODE_NAME}" "${@:3}"

