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
    
    if ! [ "$SF_LOCAL_META" == null ]; then
        DESIRED_SF_VERSION=$(echo $SF_LOCAL_META | jq -r ".version")
    
        echo "------------------------"
        echo "$SF_NAME v$DESIRED_SF_VERSION configuration checking..." 
        REQUIRED_SOFTWARE_LIST=$(echo $SF_GLOBAL_META | jq -r '.["required-software"] | .[]')
        for REQ_SF_NAME in $REQUIRED_SOFTWARE_LIST; do
            echo -n "      \"$REQ_SF_NAME\" software is required..."
            if [ -z "$(which $REQ_SF_NAME)" ]; then
               echo "$REQ_SF_NAME is not installed! You have to fix it;"
            else
                echo "Ok!"
            fi 
        done
        
        REQUIRED_FILES_LIST=$(echo $SF_GLOBAL_META | jq -r '.["required-files"] | .[]')
        for REQ_FILE_NAME in $REQUIRED_FILES_LIST; do
            echo -n "      \"$REQ_FILE_NAME\" file is required..."
            
            if ! test -f "$CARDANO_CONFIG_DIR/$REQ_FILE_NAME" && ! test -d "$CARDANO_CONFIG_DIR/$REQ_FILE_NAME" ; then
                echo "but not found...trying to fix..."
                FILE_RULE=$(echo $SF_LOCAL_META | jq -r ".\"required-files\".\"${REQ_FILE_NAME}\"")    

                FILE_RULE=$(echo "$FILE_RULE" | sed "s/#/${DESIRED_SF_VERSION}/g")
                FILE_RULE=$(echo "$FILE_RULE" | sed "s/%/${NETWORK_NAME}/g")
                FILE_RULE=($FILE_RULE)
                                
                case ${FILE_RULE[0]} in
                  d)
                    download_file ${FILE_RULE[1]} $CARDANO_CONFIG_DIR/$REQ_FILE_NAME
                    ;;

                  dtgz)
                    if [ "${REQ_FILE_NAME: -1}" == "/" ]; then
                        download_and_extract_targz ${FILE_RULE[1]} $CARDANO_CONFIG_DIR ${FILE_RULE[2]} ${FILE_RULE[3]}
                    else
                        download_and_extract_targz ${FILE_RULE[1]} $CARDANO_CONFIG_DIR/$REQ_FILE_NAME ${FILE_RULE[2]} ${FILE_RULE[3]}
                    fi
                    ;;

                  p)
                    echo "Writing file..."
                    echo ${FILE_RULE[1]} > $CARDANO_CONFIG_DIR/$REQ_FILE_NAME
                    chmod ${FILE_RULE[2]} $CARDANO_CONFIG_DIR/$REQ_FILE_NAME
                    echo "Success!"                    
                    ;;

                  *)
                    echo "Unknown instruction...cant get config file: $REQ_FILE_NAME"
                    echo $FILE_RULE
                    ;;
                esac
                
            else
                echo "Done!"
            fi
        done
    else
        echo "$SF_NAME is not required"
    fi
done 

for FILE in $(find $CARDANO_CONFIG_DIR -type f); do 
    if [ $(file -rb --mime-type $FILE) == "text/x-shellscript" ] || [ $(file -rb --mime-type $FILE) == "application/x-executable" ]; then
        chmod +x $FILE
    fi
    ln -fns $FILE $CARDANO_BINARIES_DIR/$(basename $FILE)
done




















