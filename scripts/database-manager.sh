#!/bin/bash

function database-manager {
    COMMANDS=("check" "createdb" "dropdb" "list-views" "recreatedb" "create-user" "create-migration" "run-migrations" "dump-schema" "create-snapshot" "restore-snapshot")

    if [[ ! -z "$1" && " ${COMMANDS[*]} " =~ " $1 " ]]; then
        COMMAND=$1
    else
        echo "Please, select a command:"
        echo "   1. check             - Check database exists and is set up correctly."
        echo "   2. createdb          - Create database."
        echo "   3. dropdb            - Drop database."
        echo "   4. list-views        - List the currently defined views."
        echo "   5. recreatedb        - Drop and recreate database."
        echo "   6. create-user       - Create database user (from config/pgass file)."
        echo "   7. create-migration  - Create a migration (if one is needed)."
        echo "   8. run-migrations    - Run all migrations applying as needed."
        echo "   9. dump-schema       - Dump the schema of the database."
        echo "   10. create-snapshot  - Create a db-sync state snapshot. Direct mode only with <snapshot-file> <ledger-state-file> parameters!*"
        echo "   11. restore-snapshot - Restore a db-sync state snapshot.Direct mode only with <snapshot-file> <ledger-state-dir> parameters!*"

        echo ""
        echo "   *Direct mode example: ./cardano.sh $NETWORK_NAME $MODE_NAME restore-snapshot <snapshot-file> <ledger-state-dir>"
        echo ""
        read -p "Enter the number of the desired command: " SELECTED_NUM

        if [[ $SELECTED_NUM -ge 1 ]] && [[ $SELECTED_NUM -le ${#COMMANDS[@]} ]]; then
            COMMAND="${COMMANDS[SELECTED_NUM-1]}"
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi

    echo "***************************************"
    echo "Selected action: ${COMMAND}"
    PGPASSFILE=$CARDANO_CONFIG_DIR/pgpass  \
    $CARDANO_CONFIG_DIR/postgresql-setup.sh --$COMMAND $2 $3
}

