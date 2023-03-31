#!/bin/bash

source $(dirname "$0")/startup.sh

CADDR=$CARDANO_BINARIES_DIR/cardano-address
CCLI=$CARDANO_BINARIES_DIR/cardano-cli

tput reset
read -p "Enter 24w mnemonic: " MNEMONIC
tput reset

source $(dirname "$0")/get_keys.sh















