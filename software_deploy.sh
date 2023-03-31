#!/bin/bash

#https://update-cardano-mainnet.iohk.io/cardano-node-releases/cardano-node-1.35.5-linux.tar.gz
#https://update-cardano-mainnet.iohk.io/cardano-node-releases/cardano-node-1.35.4-linux.tar.gz
#
#https://update-cardano-mainnet.iohk.io/cardano-db-sync/cardano-db-sync-13.1.0.0-linux.tar.gz
#
#https://github.com/input-output-hk/cardano-addresses/releases/download/3.12.0/cardano-addresses-3.12.0-linux64.tar.gz
#https://github.com/input-output-hk/cardano-addresses/releases/download/3.11.0/cardano-addresses-3.11.0-linux64.tar.gz
#
#
#https://api.github.com/repos/input-output-hk/cardano-addresses/releases -> tag_name -> забор прямых ссылок
#https://api.github.com/repos/input-output-hk/cardano-node/releases -> tag_name -> подстановка в ссылки для скачивания
#
#
#jq ".[].tag_name" ./releases.json #дернет версии из релизов

#проверка наличия софта

source $(dirname "$0")/startup.sh


SOFTWARE_LIST=$(from_config ".global.software | keys | .[]")
for SF_NAME in $SOFTWARE_LIST; do
    SF_GLOBAL_META=$(from_config ".global.software.\"${SF_NAME}\"")
    SF_LOCAL_META=$(from_config ".networks.\"${NETWORK_NAME}\".\"${SF_NAME}\"")    
    
    if ! [ "$SF_META" == null ]; then
        DESIRED_SF_VERSION=$(echo $SF_LOCAL_META | jq -r ".version")
        
        SF_GLOBAL_DIR=$CARDANO_SOFTWARE_DIR/$SF_NAME
        SF_LOCAL_DIR=$SF_GLOBAL_DIR/$DESIRED_SF_VERSION
        SF_BIN_DIR=$SF_LOCAL_DIR
        
        echo "------------------------"
        echo "$SF_NAME v$DESIRED_SF_VERSION is required"                  
        
        SUBPATH=$(echo $SF_GLOBAL_META | jq -r '.path')
        if ! test -f "$SF_BIN_DIR/$SUBPATH/$SF_NAME"; then            
            
            echo "Installing..."
            
            TARGZ_NAME=$(echo $SF_GLOBAL_META | jq -r '."name-format"')
            TARGZ_NAME=$(echo "$TARGZ_NAME" | sed "s/#/${DESIRED_SF_VERSION}/g")
            TARGZ_NAME=$(echo "$TARGZ_NAME" | sed "s/%/${NETWORK_NAME}/g")

            DOWNLOAD_LINK=$(echo $SF_GLOBAL_META | jq -r '."download-link"')
            DOWNLOAD_LINK=$(echo "$DOWNLOAD_LINK" | sed "s/#/${DESIRED_SF_VERSION}/g")
            DOWNLOAD_LINK=$(echo "$DOWNLOAD_LINK" | sed "s/%/${NETWORK_NAME}/g")             
              
            mkdir -p $SF_BIN_DIR

            download_and_extract_targz ${DOWNLOAD_LINK}${TARGZ_NAME} $SF_BIN_DIR
            
            echo "Done!"           
            echo "------------------------"
        else
            echo "$SF_NAME v$DESIRED_SF_VERSION is already installed;"
            echo "------------------------"   
            echo "";         
        fi

        for FILE in $(find $SF_BIN_DIR -type f); do 
            if [ $(file -rb --mime-type $FILE) == "text/x-shellscript" ] || [ $(file -rb --mime-type $FILE) == "application/x-executable" ]; then
                chmod +x $FILE
            fi
            ln -fns $FILE $CARDANO_BINARIES_DIR/$(basename $FILE)
        done        

    else
        echo "$SF_NAME is not required"
    fi
done 




















