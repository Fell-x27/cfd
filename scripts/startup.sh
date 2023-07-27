#!/bin/bash

source "$(dirname "$0")/scripts/menus-n-dialogs.sh"
source "$(dirname "$0")/scripts/network-manager.sh"
source "$(dirname "$0")/scripts/common-helpers.sh"
source "$(dirname "$0")/scripts/tx-tools.sh"
source "$(dirname "$0")/scripts/download-tools.sh"
source "$(dirname "$0")/scripts/software-tools.sh"
source "$(dirname "$0")/scripts/wallet-tools.sh"
source "$(dirname "$0")/scripts/pool-tools.sh"

for cmd in bc jq tar wget awk nano; do
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

USERNAME=$(whoami)
NETWORK_NAME="$1"

check-ip
check-deployment-path
network-manager $NETWORK_NAME

CARDANO_DIR=$(from-config '.global."cardano-dir"')

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








