#!/bin/bash

source $(dirname "$0")/startup.sh

CADDR=$CARDANO_BINARIES_DIR/cardano-address
CCLI=$CARDANO_BINARIES_DIR/cardano-cli
MNEMONIC_PATH=$CARDANO_KEYS_DIR/mnemonic.txt

MNEMONIC=$($CADDR recovery-phrase generate)

echo $MNEMONIC > $MNEMONIC_PATH
chmod 0400 $MNEMONIC_PATH
source $(dirname "$0")/get_keys.sh

echo ""
echo "Here is file with your recovery phrase: $MNEMONIC_PATH"
echo "1) Never share it;"
echo "2) Move it to the safe storage or better write to paper and remove the file;"
echo "3) Keep it secured;"
echo "4) Rememeber - if tou lose it, you lose access to your wallet..."













