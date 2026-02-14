#!/bin/bash

function service-manager {
    local OPTION_N_DESCRIPTIONS=(
        "node-relay|node-relay|Generate systemd unit for cardano-node (runner: node-relay)."
        "node-relay-local|node-relay-local|Generate systemd unit for cardano-node (runner: node-relay-local)."
        "node-block-producer|node-block-producer|Generate systemd unit for cardano-node (runner: node-block-producer)."
        "db-sync|db-sync|Generate systemd unit for cardano-db-sync (runner: db-sync)."
        "submit-api|submit-api|Generate systemd unit for cardano-submit-api (runner: submit-api)."
        "wallet|wallet|Generate systemd unit for cardano-wallet (runner: wallet)."
    )

    CHOSEN_OPTION=${1:-""}
    show-menu "$CHOSEN_OPTION" "${OPTION_N_DESCRIPTIONS[@]}"

    echo "Selected action: $MENU_SELECTED_OPTION"
    generate-service-unit "$MENU_SELECTED_COMMAND"
}

function generate-service-unit {
    local RUNNER="$1"
    local SOFTWARE_NAME
    case "$RUNNER" in
        node-relay|node-relay-local|node-block-producer)
            SOFTWARE_NAME="cardano-node"
            ;;
        db-sync)
            SOFTWARE_NAME="cardano-db-sync"
            ;;
        submit-api)
            SOFTWARE_NAME="cardano-submit-api"
            ;;
        wallet)
            SOFTWARE_NAME="cardano-wallet"
            ;;
        *)
            SOFTWARE_NAME=""
            ;;
    esac

    if [ -z "$SOFTWARE_NAME" ]; then
        echo -e "${BOLD}${WHITE_ON_RED} ERROR ${NORMAL}: unknown runner [$RUNNER]."
        return 1
    fi

    local TEMPLATE_FILE
    TEMPLATE_FILE="$CARDANO_DIR/scripts/template.service"

    if [ ! -f "$TEMPLATE_FILE" ]; then
        echo -e "${BOLD}${WHITE_ON_RED} ERROR ${NORMAL}: template file not found: $TEMPLATE_FILE"
        return 1
    fi

    local HOMEDIR="$CARDANO_DIR"
    local UNIT_FILE="$CARDANO_SERVICES_DIR/${SOFTWARE_NAME}_${NETWORK_NAME}.service"

    if ! rewriting-prompt "$UNIT_FILE" "You are about to overwrite an existing unit file: $UNIT_FILE."; then
        return 1
    fi

    sed \
        -e "s|%name%|$SOFTWARE_NAME|g" \
        -e "s|%network%|$NETWORK_NAME|g" \
        -e "s|%homedir%|$HOMEDIR|g" \
        -e "s|%runner%|$RUNNER|g" \
        -e "s|%user%|$USERNAME|g" \
        "$TEMPLATE_FILE" > "$UNIT_FILE"

    chmod 0644 "$UNIT_FILE"

    echo ""
    echo "Service unit has been generated:"
    echo "$UNIT_FILE"
    echo ""
    echo "Runner: $RUNNER"
    echo "Software: $SOFTWARE_NAME"
}
