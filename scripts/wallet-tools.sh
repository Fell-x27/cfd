#!/bin/bash


function get-keys {
    CADDR=$CARDANO_BINARIES_DIR/cardano-address
    CCLI=$CARDANO_BINARIES_DIR/cardano-cli
    PAYMENT_KEYS_DIR=$CARDANO_KEYS_DIR/payment
    MNEMONIC=$1
    mkdir -p $PAYMENT_KEYS_DIR

    #Root key 
    echo $MNEMONIC | $CADDR key from-recovery-phrase Shelley > $PAYMENT_KEYS_DIR/root.xsk

    #Private keys
    $CADDR key child 1852H/1815H/0H/0/0 < $PAYMENT_KEYS_DIR/root.xsk > $PAYMENT_KEYS_DIR/payment.xsk
    $CADDR key child 1852H/1815H/0H/2/0 < $PAYMENT_KEYS_DIR/root.xsk > $PAYMENT_KEYS_DIR/stake.xsk

    #Public keys
    $CADDR key public --with-chain-code < $PAYMENT_KEYS_DIR/payment.xsk > $PAYMENT_KEYS_DIR/payment.xvk
    $CADDR key public --with-chain-code < $PAYMENT_KEYS_DIR/stake.xsk > $PAYMENT_KEYS_DIR/stake.xvk

    #Convertation to cli-format private-keys
    $CCLI key convert-cardano-address-key --shelley-payment-key --signing-key-file $PAYMENT_KEYS_DIR/payment.xsk --out-file $PAYMENT_KEYS_DIR/payment.skey
    $CCLI key convert-cardano-address-key --shelley-stake-key --signing-key-file $PAYMENT_KEYS_DIR/stake.xsk --out-file $PAYMENT_KEYS_DIR/stake.skey

    #Base address building
    $CADDR address payment --network-tag $NETWORK_TAG < $PAYMENT_KEYS_DIR/payment.xvk > $PAYMENT_KEYS_DIR/payment.addr
    $CADDR address stake --network-tag $NETWORK_TAG < $PAYMENT_KEYS_DIR/stake.xvk > $PAYMENT_KEYS_DIR/stake.addr
    $CADDR address delegation $(cat $PAYMENT_KEYS_DIR/stake.xvk) < $PAYMENT_KEYS_DIR/payment.addr > $PAYMENT_KEYS_DIR/base.addr
    
    #vkeys extracting
    $CCLI key verification-key \
        --signing-key-file $PAYMENT_KEYS_DIR/stake.skey \
        --verification-key-file $PAYMENT_KEYS_DIR/stake.vkey

    $CCLI key non-extended-key \
        --extended-verification-key-file $PAYMENT_KEYS_DIR/stake.vkey \
        --verification-key-file $PAYMENT_KEYS_DIR/stake.vkey

    $CCLI key verification-key \
        --signing-key-file $PAYMENT_KEYS_DIR/payment.skey \
        --verification-key-file $PAYMENT_KEYS_DIR/payment.vkey

    $CCLI key non-extended-key \
        --extended-verification-key-file $PAYMENT_KEYS_DIR/payment.vkey \
        --verification-key-file $PAYMENT_KEYS_DIR/payment.vkey

    rm $PAYMENT_KEYS_DIR/{stake.xsk,payment.xsk,payment.xvk,stake.xvk,payment.addr,root.xsk}

    hide-key $PAYMENT_KEYS_DIR/payment.skey
    hide-key $PAYMENT_KEYS_DIR/stake.skey

    echo ""
    echo "Done!"
    echo -e "${UNDERLINE}Your payment address is${NORMAL}: $(cat $PAYMENT_KEYS_DIR/base.addr)\033[0m"

    echo "    Be sure that it's funded :)"
    echo "    Just send some ADA to the address above;"
    echo -e "    You can also get some free ${BOLD}testnet ADA${NORMAL} with https://docs.cardano.org/cardano-testnet/tools/faucet;"
    echo "    Remember, the Faucet works only within the official testnets!"
    echo ""

    for FILE in $(find $CARDANO_KEYS_DIR -type f); do
        chmod 0600 $FILE
    done

    return 0
}

function wallet-create {
    if rewriting-prompt "$CARDANO_KEYS_DIR/payment/payment.skey" "You are about to irreversibly delete an existing wallet!"; then
        CADDR=$CARDANO_BINARIES_DIR/cardano-address
        MNEMONIC_PATH=$CARDANO_KEYS_DIR/mnemonic.txt
        MNEMONIC=$($CADDR recovery-phrase generate)
        

        echo $MNEMONIC > $MNEMONIC_PATH
        chmod 0400 $MNEMONIC_PATH
        get-keys "$MNEMONIC"

        echo ""
        echo -e "${UNDERLINE}Here is a file with your recovery phrase${NORMAL}: ${BOLD}$MNEMONIC_PATH${NORMAL}"
        echo "    1) Never share it;"
        echo -e "    2) Move it to the safe storage or better \033[1mwrite to paper and remove the file\033[0m;"
        echo "    3) Keep it secured;"
        echo -e "    4) Rememeber - ${BOLD}if tou lose it, you lose access to your wallet${NORMAL}..."
        echo ""
    fi
}

function wallet-restore {
    if rewriting-prompt "$CARDANO_KEYS_DIR/payment/payment.skey" "You are about to irreversibly delete an existing wallet!"; then
        tput reset
        read -p "Enter 24w mnemonic: " MNEMONIC
        tput reset

        get-keys "$MNEMONIC"
    fi
}

function get-wallet-utxo {
    validate-node-sync
    wrap-cli-command get-utxo-pretty
}

function get-wallet-address-data {
    inspect_cardano_address
}