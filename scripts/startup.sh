#!/bin/bash

source "$(dirname "$0")/scripts/common-helpers.sh"
source "$(dirname "$0")/scripts/download-tools.sh"
source "$(dirname "$0")/scripts/software-tools.sh"
source "$(dirname "$0")/scripts/tx-tools.sh"

for cmd in jq tar wget awk nano; do
  if ! command -v $cmd &> /dev/null; then
      echo "Error: $cmd is not installed. Please install it and try again."
      exit 1
  fi
done


CONFIG_FILE="conf.json"
CONFIG_FILE_DEF="scripts/conf.json_default"

if [ ! -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE_DEF" "$CONFIG_FILE"
fi

check-ip
check-deployment-path

USERNAME=$(whoami)
AVAILABLE_NETWORKS=$(jq -r '.networks | keys[]' "$CONFIG_FILE")
NETWORKS_ARR=($AVAILABLE_NETWORKS)

if [ ! -z "$1" ] && [[ " ${NETWORKS_ARR[@]} " =~ " $1 " ]]; then
    NETWORK_NAME="$1"
else
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
        if [ ! -z "$1" ] && [[ ! " ${NETWORKS_ARR[@]} " =~ " $1 " ]]; then
            echo "Unknown network."
        else
            echo "Network not selected."
        fi
        echo "Invalid selection. Exiting."
        exit 1
    fi
fi
echo ""
echo "***************************************"
echo "Selected network: $NETWORK_NAME"		
	


CARDANO_VERSION=$(from-config ".networks.${NETWORK_NAME}.version")
CARDANO_DIR=$(from-config '.global."cardano-dir"')


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


prepare_software "cardano-node" "issues" 

if test -f $CARDANO_CONFIG_DIR/shelley-genesis.json; then
    if [ "$NETWORK_NAME" == "mainnet" ]; then
      MAGIC=(--mainnet)
      NETWORK_TAG=1
      NETWORK_TYPE="mainnet"
    else
      MAGIC=(--testnet-magic $(cat $CARDANO_CONFIG_DIR/shelley-genesis.json | jq .networkMagic))
      NETWORK_TAG=0
      NETWORK_TYPE="testnet"
    fi
fi








