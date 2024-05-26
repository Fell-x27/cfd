declare -a DIFF_BUFFER
declare -a CHANGES_BUFFER

function compare_json_recursive() {
    local OLD_DEF_JSON=$1
    local NEW_DEF_JSON=$2
    local OLD_USER_JSON=$3
    local SELECTOR=$4
    
    local OLD_DEF_VALUE
    local NEW_DEF_VALUE
    local OLD_USER_VALUE
    local JSON_TYPE  
    local IS_COMPLEX
    
    JSON_TYPE=$(echo $OLD_DEF_JSON | jq -r 'type')
    if [ "$JSON_TYPE" == "object" ] || [ "$JSON_TYPE" == "array" ]; then
        IS_COMPLEX=1
    else
        IS_COMPLEX=0
    fi

    if [ $IS_COMPLEX -eq 1 ]; then    
        local OLD_DEF_KEYS=$(echo $OLD_DEF_JSON | jq -r 'keys[]')
        local NEW_DEF_KEYS=$(echo $NEW_DEF_JSON | jq -r 'keys[]')
        local OLD_USER_KEYS=$(echo $OLD_USER_JSON | jq -r 'keys[]')
        
        local OLD_DEF_COUNT=$(echo $OLD_DEF_KEYS | wc -w)
        local NEW_DEF_COUNT=$(echo $NEW_DEF_KEYS | wc -w)
            
        if [ $OLD_DEF_COUNT -ne $NEW_DEF_COUNT ]; then
            DIFF_BUFFER+=("$SELECTOR: The new file has $NEW_DEF_COUNT nodes compared to $OLD_DEF_COUNT in the old file.\n\n")       
        fi    

        for KEY in $OLD_DEF_KEYS; do
            if ! echo $NEW_DEF_KEYS | grep -q -w $KEY; then
                
                DIFF_BUFFER+=("$SELECTOR/$KEY is not present in new configuration.\n\n")
            fi
        done
        
        for KEY in $NEW_DEF_KEYS; do
            if ! echo $OLD_DEF_KEYS | grep -q -w $KEY; then
                DIFF_BUFFER+=("$SELECTOR/$KEY was added in new configuration.\n\n")           
            fi    

            if [ "$JSON_TYPE" == "object" ]; then
                local KEY_ESCAPED='"'$KEY'"'
            elif [ "$JSON_TYPE" == "array" ]; then
                local KEY_ESCAPED="[$KEY]"
            fi
            
            
            
            OLD_DEF_VALUE=$(echo $OLD_DEF_JSON | jq ".$KEY_ESCAPED")
            NEW_DEF_VALUE=$(echo $NEW_DEF_JSON | jq ".$KEY_ESCAPED")
            OLD_USER_VALUE=$(echo $OLD_USER_JSON | jq ".$KEY_ESCAPED")

            echo -n "."
           
            if [ "$OLD_DEF_VALUE" != "$NEW_DEF_VALUE" ] || [ "$OLD_DEF_VALUE" != "$OLD_USER_VALUE" ]; then
                compare_json_recursive "$OLD_DEF_VALUE" "$NEW_DEF_VALUE" "$OLD_USER_VALUE" "$SELECTOR.$KEY_ESCAPED"                
            fi
           
        done
    else    
        OLD_DEF_VALUE=$OLD_DEF_JSON
        NEW_DEF_VALUE=$NEW_DEF_JSON
        OLD_USER_VALUE=$OLD_USER_JSON        
       
        if [ "$OLD_DEF_VALUE" != "$NEW_DEF_VALUE" ]; then
            DIFF_BUFFER+=("$SELECTOR has changed from default $OLD_DEF_VALUE to default $NEW_DEF_VALUE.\n\n")          
        fi       

        
        if [ "$OLD_DEF_VALUE" != "$OLD_USER_VALUE" ]; then
            DIFF_BUFFER+=("$SELECTOR has changed custom $OLD_USER_VALUE.\n\n")          
            CHANGES_BUFFER+=("${SELECTOR}%|#${OLD_USER_VALUE}")
        fi
    fi    
}


function check_and_compare_json() {
    local OLD_DEF_JSON_FILE=$1
    local NEW_DEF_JSON_FILE=$2
    local OLD_USER_JSON_FILE=$3
    local NEW_USER_JSON_FILE=$4
    local FILE_NAME=$(basename $OLD_DEF_JSON_FILE)
    echo "Checking for conflicts..."
    
    local OLD_DEF_JSON=$(jq '.' $OLD_DEF_JSON_FILE)
    local NEW_DEF_JSON=$(jq '.' $NEW_DEF_JSON_FILE)
    local OLD_USER_JSON=$(jq '.' $OLD_USER_JSON_FILE)
    local NEW_USER_JSON=$(jq '.' $NEW_USER_JSON_FILE)
    

    compare_json_recursive "$OLD_DEF_JSON" "$NEW_DEF_JSON" "$OLD_USER_JSON" ""

    echo ""

    if [ ${#DIFF_BUFFER[@]} -eq 0 ]; then
        echo "$FILE_NAME have not changed."
    else
        for i in "${DIFF_BUFFER[@]}"; do
            echo -e "$i"
        done
    fi

 
    for CHANGE in "${CHANGES_BUFFER[@]}"; do
        NODE_PATH=${CHANGE%%"%|#"*}
        NEW_VALUE=${CHANGE#*"%|#"}     
       
        jq "$NODE_PATH = $NEW_VALUE" $NEW_USER_JSON_FILE > tmp.json && mv tmp.json $NEW_USER_JSON_FILE        
    done


    if [ ${#DIFF_BUFFER[@]} -ne 0 ] || [ ${#CHANGES_BUFFER[@]} -ne 0 ]; then
        echo "It's VERY IMPORTANT to check the configuration file for any errors."
        read -p "Do you want to open it in nano? [Y/n] " choice

        choice=$(echo "$choice" | xargs)

        if [ -z "$choice" ]; then
            choice='y'
        fi
        case "$choice" in 
            y|Y ) nano $NEW_USER_JSON_FILE;;
            * ) echo "Okay, please make sure to check it later.";;
        esac
    fi

    DIFF_BUFFER=()
    CHANGES_BUFFER=()
}


function prepare_software {
    local redirect_output    

    if [ "$2" == "silent" ]; then
        redirect_output=">/dev/null 2>&1"
    else
        redirect_output=""
    fi

    if eval software_deploy "$1" "$2" $redirect_output && eval software_config "$1" "$2" $redirect_output; then
        return 0
    else
        echo "The called software is not ready to launch. Please, fix the issues before."
        return 1
    fi
}

function is-installed {
    local SF_NAME=$1
    local SF_GLOBAL_META=$(from-config ".global.software.\"${SF_NAME}\"")
    local SF_LOCAL_META=$(from-config ".networks.\"${NETWORK_NAME}\".software.\"${SF_NAME}\"")    
    
    if ! [ "$SF_META" == null ]; then
        local DESIRED_SF_VERSION=$(get-sf-version $SF_NAME)
        
        local SF_GLOBAL_DIR=$CARDANO_SOFTWARE_DIR/$SF_NAME
        local SF_LOCAL_DIR=$SF_GLOBAL_DIR/$DESIRED_SF_VERSION
        local SF_BIN_DIR=$SF_LOCAL_DIR/bin
        
        echo ""
        echo "------------------------"
        echo "$SF_NAME ver: $DESIRED_SF_VERSION is required"                  

            
        local SUBPATH=$(echo $SF_GLOBAL_META | jq -r '.path')
        SUBPATH=$(replace-placeholders "$SUBPATH" "$DESIRED_SF_VERSION" "$NETWORK_NAME")
        
    fi
    
}


function software_deploy(){
    local SF_NAME=$1
    local VERBOSITY=${2:-"all"}
    local SF_GLOBAL_META=$(from-config ".global.software.\"${SF_NAME}\"")
    local SF_LOCAL_META=$(from-config ".networks.\"${NETWORK_NAME}\".software.\"${SF_NAME}\"")    
    
    if ! [ "$SF_LOCAL_META" == null ]; then
        local DESIRED_SF_VERSION=$(get-sf-version $SF_NAME)
        DESIRED_SF_VERSION_BASE=$(echo $DESIRED_SF_VERSION | awk -F'-' '{print $1}')
        DESIRED_SF_VERSION_SUFFIX=$(echo "$VERSION" | awk -F'-' '{if (NF>1) print "-"$2; else print ""}')
        
        local SF_GLOBAL_DIR=$CARDANO_SOFTWARE_DIR/$SF_NAME
        local SF_LOCAL_DIR=$SF_GLOBAL_DIR/$DESIRED_SF_VERSION
        local SF_BIN_DIR=$SF_LOCAL_DIR/bin
        
        if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
            echo ""
            echo "------------------------"
            echo "$SF_NAME ver: $DESIRED_SF_VERSION is required"
        fi 

            
        local SUBPATH=$(echo $SF_GLOBAL_META | jq -r '.path')
        SUBPATH=$(replace-placeholders "$SUBPATH" "$DESIRED_SF_VERSION" "$NETWORK_NAME")
        
        if ! test -f "$SF_BIN_DIR/$SUBPATH/$SF_NAME"; then            
            
            if [ "$VERBOSITY" != "silent" ]; then
                echo ""
                echo "$SF_NAME ver: $DESIRED_SF_VERSION  not found"   
                echo "Installing..."   
                echo ""
            fi 
            
            mkdir -p $SF_BIN_DIR  
            
            local TARGZ_NAME=$(echo $SF_GLOBAL_META | jq -r '."name-format"')
            TARGZ_NAME=$(replace-placeholders "$TARGZ_NAME" "$DESIRED_SF_VERSION_BASE" "$NETWORK_NAME")

            local DOWNLOAD_LINKS_RAW=$(echo $SF_GLOBAL_META | jq -r '."download-links"[]')


            for LINK in $DOWNLOAD_LINKS_RAW; do
                DOWNLOAD_LINK=$(replace-placeholders "$LINK" "$DESIRED_SF_VERSION" "$NETWORK_NAME")$TARGZ_NAME
                if curl --output /dev/null --silent --head --fail "$DOWNLOAD_LINK"; then
                    break
                fi
            done

            download_and_extract_targz $DOWNLOAD_LINK $SF_BIN_DIR
           
            
            if [ "$VERBOSITY" != "silent" ]; then
                echo ""
                echo "Done!"           
                echo "------------------------"    
            fi         
        else   
            if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then 
                echo "$SF_NAME ver: $DESIRED_SF_VERSION is already installed;"
                echo "------------------------"   
                echo "";                     
            fi
        fi
        
        local DESIRED_FILES=$(echo $SF_GLOBAL_META | jq -r '.["desired-files"] | .[]')
        
        if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
            echo "Validating $SF_NAME installation..."
            spin &
            spinner_pid=$!
        fi

        if [ "$DESIRED_FILES" != "*" ]; then
            FILES=$(echo "$DESIRED_FILES" | xargs -I{} find "$SF_BIN_DIR" -type f -name '{}')
        else
            FILES=$(find "$SF_BIN_DIR" -type f)
        fi

        for FILE in $FILES; do
            local BASENAME=$(basename $FILE)
            local OLD_LINK=$(readlink $CARDANO_BINARIES_DIR/$BASENAME)
            local OLD_VERSION=$(get-version-from-path "$OLD_LINK" "$SF_GLOBAL_DIR")
            
            if [ -z $OLD_VERSION ] || [ $OLD_VERSION != $DESIRED_SF_VERSION ]; then
                if [ $(file -rb --mime-type $FILE) == "text/x-shellscript" ] || [ $(file -rb --mime-type $FILE) == "application/x-executable" ]; then
                    chmod +x $FILE                    
                fi
                ln -fns $FILE $CARDANO_BINARIES_DIR/$BASENAME
            fi
        done
       
        if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
            kill "$spinner_pid" >/dev/null 2>&1
            echo -ne "OK" "\r"
        fi
        
    else
        if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
            echo "$SF_NAME is not required"
        fi
    fi   
    return 0
}

function recursive-config-linking {
    local CONF_DIR=$1
    local SF_CONF_DIR_USER=$2
    local DESIRED_SF_VERSION=$3
    local SF_GLOBAL_DIR=$4
    local LINKS_DIR=$5
    

    for SUBJECT in "$CONF_DIR"/*; do         
    
        local BASENAME=$(basename "$SUBJECT")                
        local LINK_CONF_SUBJECT=$LINKS_DIR/$BASENAME
        
        
        if [ "$BASENAME" == "*" ]; then
            return 0
        fi
        
        local OLD_USER_CONF_SUBJECT=$(readlink "$LINK_CONF_SUBJECT")        
        local OLD_DEF_CONF_SUBJECT=$(echo "$OLD_USER_CONF_SUBJECT" | sed "s|user_configs|default_configs|")        
        local NEW_USER_CONF_SUBJECT=$SF_CONF_DIR_USER/$BASENAME   
        local NEW_DEF_CONF_SUBJECT=$SUBJECT

        local OLD_VERSION=$(get-version-from-path "$OLD_USER_CONF_SUBJECT" "$SF_GLOBAL_DIR")  
        
        ln -fns "$NEW_USER_CONF_SUBJECT" "$LINK_CONF_SUBJECT"         
        
        if [ ! -e "$NEW_USER_CONF_SUBJECT" ]; then
            cp -r "$NEW_DEF_CONF_SUBJECT" "$NEW_USER_CONF_SUBJECT"
        fi

        if [ -f "$SUBJECT" ]; then        
            if [ $(file -rbL --mime-type "$NEW_DEF_CONF_SUBJECT") == "text/x-shellscript" ] || [ $(file -rbL --mime-type "$NEW_DEF_CONF_SUBJECT") == "application/x-executable" ]; then
                chmod +x "$SUBJECT"
                chmod +x "$LINK_CONF_SUBJECT"
            fi
        
            if [ -n "$OLD_VERSION" ] && [ "$OLD_VERSION" != "$DESIRED_SF_VERSION" ] && [ -e "$OLD_USER_CONF_SUBJECT" ] && jq -e . >/dev/null 2>&1 < "$NEW_DEF_CONF_SUBJECT"; then                           
                check_and_compare_json "$OLD_DEF_CONF_SUBJECT" "$NEW_DEF_CONF_SUBJECT" "$OLD_USER_CONF_SUBJECT" "$NEW_USER_CONF_SUBJECT"
            fi              
        elif [ -d "$SUBJECT" ]; then
            recursive-config-linking $SUBJECT $SF_CONF_DIR_USER $DESIRED_SF_VERSION $SF_GLOBAL_DIR $LINKS_DIR/$BASENAME      
        fi  
    done
}



function software_config() {
    local SF_NAME=$1
    local VERBOSITY=${2:-"all"}
    local SF_GLOBAL_META=$(from-config ".global.software.\"${SF_NAME}\"")
    local SF_LOCAL_META=$(from-config ".networks.\"${NETWORK_NAME}\".software.\"${SF_NAME}\"")
    local RELINK_NEEDED=0
    
    if ! [ "$SF_LOCAL_META" == null ]; then
        local DESIRED_SF_VERSION=$(get-sf-version $SF_NAME)
        DESIRED_SF_VERSION_BASE=$(echo $DESIRED_SF_VERSION | awk -F'-' '{print $1}')
        DESIRED_SF_VERSION_SUFFIX=$(echo "$VERSION" | awk -F'-' '{if (NF>1) print "-"$2; else print ""}')

        local SF_GLOBAL_DIR=$CARDANO_SOFTWARE_DIR/$SF_NAME
        local SF_LOCAL_DIR=$SF_GLOBAL_DIR/$DESIRED_SF_VERSION
        local SF_CONF_DIR_DEF=$SF_LOCAL_DIR/default_configs/$NETWORK_NAME
        local SF_CONF_DIR_USER=$SF_LOCAL_DIR/user_configs/$NETWORK_NAME
    
        mkdir -p $SF_CONF_DIR_DEF
        mkdir -p $SF_CONF_DIR_USER
    
        if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
            echo ""
            echo "------------------------"
            echo "$SF_NAME version: $DESIRED_SF_VERSION configuration checking..." 
        fi
        
        local REQUIRED_SOFTWARE_LIST=$(echo $SF_GLOBAL_META | jq -r '.["required-software"] | .[]')
        for REQ_SF_NAME in $REQUIRED_SOFTWARE_LIST; do
            if [ "$VERBOSITY" != "silent" ]; then
                echo -n "      \"$REQ_SF_NAME\" software is required..."
                if [ -z "$(which $REQ_SF_NAME)" ]; then
                   echo -e "\e[1;41m$REQ_SF_NAME is not installed! You have to fix it;\e[1;m"
                   return 1
                else
                    echo "Ok!"
                fi 
            fi
        done

        local REQUIRED_FILES_LIST=$(echo $SF_GLOBAL_META | jq -r '.["required-files"] | .[]')
        for REQ_FILE_NAME in $REQUIRED_FILES_LIST; do
            if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
                echo -n "      \"$REQ_FILE_NAME\" file is required..."
            fi
            
            if ! test -f "$SF_CONF_DIR_DEF/$REQ_FILE_NAME" && ! test -d "$SF_CONF_DIR_DEF/$REQ_FILE_NAME" ; then
                
                if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
                    echo "      \"$REQ_FILE_NAME\" file not found...trying to fix..."
                    echo ""   
                fi
                
                             

                local FILE_RULE=$(echo $SF_LOCAL_META | jq -r ".\"required-files\".\"${REQ_FILE_NAME}\"")    

                FILE_RULE=$(echo "$FILE_RULE" | awk -v base="$DESIRED_SF_VERSION_BASE" -v network="$NETWORK_NAME" -v suffix="$DESIRED_SF_VERSION_SUFFIX" '{
                    gsub(/#/, base);
                    gsub(/%/, network);
                    gsub(/\^/, suffix);
                    print
                }')

                local FILE_RULE=($FILE_RULE)
                                
                case ${FILE_RULE[0]} in
                  d)
                    download_file ${FILE_RULE[1]} $SF_CONF_DIR_DEF/$REQ_FILE_NAME
                    ;;

                  dtgz)
                    if [ "${REQ_FILE_NAME: -1}" == "/" ]; then
                        download_and_extract_targz ${FILE_RULE[1]} $SF_CONF_DIR_DEF ${FILE_RULE[2]} ${FILE_RULE[3]}
                    else
                        download_and_extract_targz ${FILE_RULE[1]} $SF_CONF_DIR_DEF/$REQ_FILE_NAME ${FILE_RULE[2]} ${FILE_RULE[3]}
                    fi
                    ;;

                  p)
                    echo "Writing file..."
                    echo ${FILE_RULE[1]} > $SF_CONF_DIR_DEF/$REQ_FILE_NAME
                    chmod ${FILE_RULE[2]} $SF_CONF_DIR_DEF/$REQ_FILE_NAME
                    echo "Success!"                    
                    ;;

                  *)
                    echo "Unknown instruction...can't get config file: $REQ_FILE_NAME"
                    echo $FILE_RULE
                    return 1
                    ;;
                esac
            else
                if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
                    echo "Done!"
                fi
            fi
        done
    else
        if [ "$VERBOSITY" != "silent" ] && [ "$VERBOSITY" != "issues" ]; then
            echo "$SF_NAME is not required"
        fi        
    fi

    recursive-config-linking $SF_CONF_DIR_DEF $SF_CONF_DIR_USER $DESIRED_SF_VERSION $SF_GLOBAL_DIR $CARDANO_CONFIG_DIR
    return 0
}

