#!/bin/bash

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it and try again."
    exit 1
fi


if ! command -v tar &> /dev/null; then
    echo "Error: tar is not installed. Please install it and try again."
    exit 1
fi


if ! command -v wget &> /dev/null; then
    echo "Error: wget is not installed. Please install it and try again."
    exit 1
fi


CONFIG_FILE="$(dirname "$0")/conf.json"
AVAILABLE_NETWORKS=$(jq -r '.networks | keys[]' "$CONFIG_FILE")
NETWORKS_ARR=($AVAILABLE_NETWORKS)

function from_config() {
    local PARAM_PATH=$1
    echo $(jq -r "$PARAM_PATH" "$CONFIG_FILE")   
}

if [ -z "${NETWORK_NAME:-}" ]; then
    if [ ! -z "$1" ] && [[ " ${NETWORKS_ARR[@]} " =~ " $1 " ]]; then
        NETWORK_NAME="$1"
    else
        if [[ ! " ${NETWORKS_ARR[@]} " =~ " $1 " ]]; then
            echo "Unknown network."
        else
            echo "Network not selected."
        fi

        echo "Available networks:"

        COUNTER=1
        for NETWORK in "${NETWORKS_ARR[@]}"; do
            echo "$COUNTER. $NETWORK"
            ((COUNTER++))
        done

        echo -n "Enter the number corresponding to the desired network:"
        read SELECTED_NUM

        if [[ $SELECTED_NUM -ge 1 ]] && [[ $SELECTED_NUM -le ${#NETWORKS_ARR[@]} ]]; then
            NETWORK_NAME="${NETWORKS_ARR[SELECTED_NUM-1]}"
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi
    echo "Selected network: $NETWORK_NAME"
fi
		
	


CARDANO_VERSION=$(from_config ".networks.${NETWORK_NAME}.version")
CARDANO_DIR=$(from_config '.global."cardano-dir"')

if [ ! -d "$CARDANO_DIR" ] || [ ! -w "$CARDANO_DIR" ]; then
  echo "Error: $CARDANO_DIR does not exist or is not writable;"
  echo "Please, set another path in the $CONFIG_FILE"
  exit 1
fi


CARDANO_GIT_DIR=$CARDANO_DIR/git

CARDANO_SCRIPTS_DIR=$CARDANO_DIR/software/scripts/polished

CARDANO_SOFTWARE_DIR=$CARDANO_DIR/software
CARDANO_NETWORKS_DIR=$CARDANO_DIR/networks/$NETWORK_NAME

CARDANO_STORAGE_DIR=$CARDANO_NETWORKS_DIR/storage
CARDANO_BINARIES_DIR=$CARDANO_NETWORKS_DIR/bin
CARDANO_CONFIG_DIR=$CARDANO_NETWORKS_DIR/config
CARDANO_POOL_DIR=$CARDANO_NETWORKS_DIR/pool
CARDANO_KEYS_DIR=$CARDANO_NETWORKS_DIR/keys
CARDANO_SOCKET_PATH=$CARDANO_NETWORKS_DIR/cardano.socket

mkdir -p $CARDANO_SOFTWARE_DIR
mkdir -p $CARDANO_NETWORKS_DIR
mkdir -p $CARDANO_STORAGE_DIR
mkdir -p $CARDANO_BINARIES_DIR
mkdir -p $CARDANO_CONFIG_DIR
mkdir -p $CARDANO_POOL_DIR
mkdir -p $CARDANO_KEYS_DIR


if test -f $CARDANO_CONFIG_DIR/shelley-genesis.json; then
    if [ "$NETWORK_NAME" == "mainnet" ]; then
      MAGIC=(--mainnet)
      NETWORK_TAG=1
    else
      MAGIC=(--testnet-magic $(cat $CARDANO_CONFIG_DIR/shelley-genesis.json | jq .networkMagic))
      NETWORK_TAG=0
    fi
fi


function download_file() {
    URL=$1
    FILE_PATH=$2

    echo "Trying to download from $URL"
    wget -q $URL -O $FILE_PATH
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "Error: Unable to download file from $URL"
        return 1
    fi

    echo "Success!"
    return 0
}

function download_and_extract_targz() {
    URL=$1    
    DEST_DIR=$2
    ARCHIVE_DIR=$3
    STRIP_COMPONENTS=$4
    
    if ! [ -z "$STRIP_COMPONENTS" ];then
        STRIP_COMPONENTS="--strip-components=$STRIP_COMPONENTS"
    fi
    
    echo "Trying to download from $URL"
    TEMP_ARCHIVE="$(mktemp).tar.gz"
    wget -q $URL -O $TEMP_ARCHIVE
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "Error: Unable to download archive from $URL"
        return 1
    else
        echo "Success!"
    fi

    echo "Extracting..."
    tar -xf $TEMP_ARCHIVE -C $DEST_DIR $ARCHIVE_DIR $STRIP_COMPONENTS

    EXTRACT_STATUS=$?

    if [ $EXTRACT_STATUS -ne 0 ]; then
        echo "Error: Unable to extract archive $TEMP_ARCHIVE"
        return 1
    else 
        echo "Success!"
    fi

    rm $TEMP_ARCHIVE
    return 0
}

function get_binary(){
    SF_NAME=$1        
    SUBPATH=$(echo $(from_config ".global.software.\"${SF_NAME}\"") | jq -r '.path')

    $CARDANO_BINARIES_DIR/$SF_NAME/$SUBPATH/
}

function build_arg_array() {
    local param_name="$1"
    shift
    local values=("$@")
    local result=()

    for value in "${values[@]}"; do
        result+=( "$param_name" "$value" )
    done

    echo "${result[@]}"
}







