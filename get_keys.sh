#!/bin/bash

PAYMENT_KEYS_DIR=$CARDANO_KEYS_DIR/payment
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
$CADDR address delegation $(cat $PAYMENT_KEYS_DIR/stake.xvk) < $PAYMENT_KEYS_DIR/payment.addr > $PAYMENT_KEYS_DIR/base.addr

rm $PAYMENT_KEYS_DIR/{stake.xsk,payment.xsk,payment.xvk,stake.xvk,payment.addr,root.xsk}


echo "Done!"
echo "Your keys are stored in: $PAYMENT_KEYS_DIR"
echo "Your payment address is $(cat $PAYMENT_KEYS_DIR/base.addr)"
echo "Be sure that it's funded :)"

for FILE in $(find $CARDANO_KEYS_DIR -type f); do
    chmod 0600 $FILE
done
