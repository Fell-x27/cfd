#!/bin/bash

source $(dirname "$0")/startup.sh
COMMANDS=("--check" "--createdb" "--dropdb" "--list-views" "--recreatedb" "--create-user" "--create-migration" "--run-migrations" "--dump-schema")
COMMAND=$2

if [[ ! " ${COMMANDS[*]} " =~ " ${COMMAND} " ]]; then
    echo "Please, add a command:"
    echo "   --check             - Check database exists and is set up correctly."
    echo "   --createdb          - Create database."
    echo "   --dropdb            - Drop database."
    echo "   --list-views        - List the currently definied views."
    echo "   --recreatedb        - Drop and recreate database."
    echo "   --create-user       - Create database user (from config/pgass file)."
    echo "   --create-migration  - Create a migration (if one is needed)."
    echo "   --run-migrations    - Run all migrations applying as needed."
    echo "   --dump-schema       - Dump the schema of the database."
    echo ""
    echo "   - Create a db-sync state snapshot"
    echo "         --create-snapshot <snapshot-file> <ledger-state-file>"
    echo ""
    echo "   - Restore a db-sync state snapshot."
    echo "         --restore-snapshot <snapshot-file> <ledger-state-dir>"

else
    PGPASSFILE=$CARDANO_CONFIG_DIR/pgpass  \
    $CARDANO_CONFIG_DIR/postgresql-setup.sh $COMMAND $3 $4
fi





