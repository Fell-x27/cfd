#!/bin/bash


function build-config() {
    local CONFIG_FILE_DEF=$1
    local CONFIG_FILE=$2
    local VERSIONS_LIST=$3

    if command -v jq >/dev/null 2>&1; then
        if [ ! -f "$VERSIONS_LIST" ]; then
            echo "Error: $VERSIONS_LIST does not exist."
            exit 1
        fi

        # Validate JSON files
        if ! jq empty "$VERSIONS_LIST" >/dev/null 2>&1; then
            echo "Error: $VERSIONS_LIST contains invalid JSON."
            exit 1
        fi

        if ! jq empty "$CONFIG_FILE_DEF" >/dev/null 2>&1; then
            echo "Error: $CONFIG_FILE_DEF contains invalid JSON."
            exit 1
        fi

        # Use jq to update the configuration file with versions
        jq --slurpfile versions "$VERSIONS_LIST" '
            .networks |=
            ( 
                # Iterate over each network
                to_entries | map(
                    .key as $networkName |
                    .value |= (
                        .software |= (
                            # Iterate over each software in the network
                            to_entries | map(
                                .key as $softwareName |
                                .value |= (
                                    # Update the version if it exists in actual_versions.json
                                    if $versions[0][$networkName][$softwareName] then
                                        .version = $versions[0][$networkName][$softwareName]
                                    else
                                        .
                                    end
                                )
                            ) | from_entries
                        )
                    )
                ) | from_entries
            )
        ' "$CONFIG_FILE_DEF" > "$CONFIG_FILE"
    else
        echo "jq is not installed. Please install jq to proceed."
        exit 1
    fi
}


function check-config() {
    local CONFIG_FILE=$1
    local CONFIG_FILE_DEF=$2
    local CONFIG_FILE_DEF_PREV="${CONFIG_FILE_DEF}_prev"
    local VERSIONS_LIST="$(dirname "$0")/scripts/actual_versions.json"

    if [ ! -f "$CONFIG_FILE_DEF_PREV" ]; then
        cp "$CONFIG_FILE_DEF" "$CONFIG_FILE_DEF_PREV"
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        build-config "$CONFIG_FILE_DEF" "$CONFIG_FILE" "$VERSIONS_LIST"
    else
        check_and_compare_json "$CONFIG_FILE_DEF_PREV" "$CONFIG_FILE_DEF" "$CONFIG_FILE" "$CONFIG_FILE" "silent"
        if [ $? -eq 0 ]; then
            cp "$CONFIG_FILE_DEF" "$CONFIG_FILE_DEF_PREV"
        fi
    fi
}





