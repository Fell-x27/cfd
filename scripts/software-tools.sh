function compare_json_recursive() {
    local JSON1_JSON=$1
    local JSON2_JSON=$2
    local SELECTOR=$3
    local CHANGES_BUFFER=$4
    
    local JSON1_VALUE
    local JSON2_VALUE
    local JSON_TYPE
    
    JSON_TYPE=$(echo $JSON2_JSON | jq -r 'type' 2>/dev/null)

    echo -n "*" >&2

    if [ "$JSON_TYPE" == "object" ] || [ "$JSON_TYPE" == "array" ]; then
        local JSON1_KEYS=""
        local JSON2_KEYS=""

        if [ "$(echo $JSON1_JSON | jq -r 'type' 2>/dev/null)" == "object" ] || [ "$(echo $JSON1_JSON | jq -r 'type' 2>/dev/null)" == "array" ]; then
            JSON1_KEYS=$(echo $JSON1_JSON | jq -r 'keys[]' 2>/dev/null)
        fi

        if [ "$JSON_TYPE" == "object" ] || [ "$JSON_TYPE" == "array" ]; then
            JSON2_KEYS=$(echo $JSON2_JSON | jq -r 'keys[]' 2>/dev/null)
        fi
        
        # Combine keys from both JSONs
        local ALL_KEYS=$(echo -e "$JSON1_KEYS\n$JSON2_KEYS" | sort | uniq)
        
        for KEY in $ALL_KEYS; do
            if [ "$JSON_TYPE" == "object" ]; then
                local KEY_ESCAPED="\"${KEY}\""
            elif [ "$JSON_TYPE" == "array" ]; then
                local KEY_ESCAPED="[$KEY]"
            fi

            JSON1_VALUE=$(echo $JSON1_JSON | jq ".$KEY_ESCAPED" 2>/dev/null)
            JSON2_VALUE=$(echo $JSON2_JSON | jq ".$KEY_ESCAPED" 2>/dev/null)

            echo -n "." >&2
            
            local VALUE_TYPE_JSON1=$(echo $JSON1_VALUE | jq -r 'type' 2>/dev/null)
            local VALUE_TYPE_JSON2=$(echo $JSON2_VALUE | jq -r 'type' 2>/dev/null)
            
            if [ "$VALUE_TYPE_JSON1" == "object" ] || [ "$VALUE_TYPE_JSON1" == "array" ] || [ "$VALUE_TYPE_JSON2" == "object" ] || [ "$VALUE_TYPE_JSON2" == "array" ]; then
                local TEMP_BUFFER
                TEMP_BUFFER=$(compare_json_recursive "$JSON1_VALUE" "$JSON2_VALUE" "$SELECTOR.$KEY_ESCAPED" "")
                if [ -n "$TEMP_BUFFER" ]; then
                    CHANGES_BUFFER+="${TEMP_BUFFER}\n"
                fi
            else
                if [ "$JSON1_VALUE" != "$JSON2_VALUE" ]; then
                    echo -n "!" >&2
                    if [ "$JSON1_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON2" != "null" ]; then
                        # Key is only in JSON2
                        CHANGES_BUFFER+="+${SELECTOR}.${KEY_ESCAPED}%|#${JSON2_VALUE}\n"
                    elif [ "$JSON2_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON1" != "null" ]; then
                        # Key is only in JSON1
                        CHANGES_BUFFER+="-${SELECTOR}.${KEY_ESCAPED}\n"
                    else
                        # Key is in both, but values are different
                        CHANGES_BUFFER+="^${SELECTOR}.${KEY_ESCAPED}%|#${JSON1_VALUE}||${JSON2_VALUE}\n"
                    fi
                fi
            fi
        done
    else    
        JSON1_VALUE=$JSON1_JSON
        JSON2_VALUE=$JSON2_JSON        
        local VALUE_TYPE_JSON1=$(echo $JSON1_VALUE | jq -r 'type' 2>/dev/null)
        local VALUE_TYPE_JSON2=$(echo $JSON2_VALUE | jq -r 'type' 2>/dev/null)

        if [ "$JSON1_VALUE" != "$JSON2_VALUE" ]; then
            echo -n "!" >&2
            if [ "$JSON1_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON2" != "null" ]; then
                # Key is only in JSON2
                CHANGES_BUFFER+="+${SELECTOR}%|#${JSON2_VALUE}\n"
            elif [ "$JSON2_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON1" != "null" ]; then
                # Key is only in JSON1
                CHANGES_BUFFER+="-${SELECTOR}\n"
            else
                # Key is in both, but values are different
                CHANGES_BUFFER+="^${SELECTOR}%|#${JSON1_VALUE}||${JSON2_VALUE}\n"
            fi
        fi
    fi
    

    CHANGES_BUFFER=$(echo -e "$CHANGES_BUFFER" | sed '/^$/d')
    
    echo -e "$CHANGES_BUFFER"
}



function apply_diff() {
    local DIFF_TEXT="$1"
    local JSON_INPUT="$2"

    IFS=$'\n' read -d '' -r -a DIFF_LINES <<< "$DIFF_TEXT"


    local UPDATED_JSON="$JSON_INPUT"


    for DIFF_LINE in "${DIFF_LINES[@]}"; do
        local ACTION="${DIFF_LINE:0:1}"
        local JPATH="${DIFF_LINE:1}"
        local KEY_PATH="${JPATH%%"%|#"*}"
        local VALUE="${JPATH#*"%|#"*}"

        KEY_PATH=$(echo "$KEY_PATH" | sed 's/\.\[/[/g')

        case "$ACTION" in
            +)
                UPDATED_JSON=$(echo "$UPDATED_JSON" | jq "$KEY_PATH = $VALUE")
                ;;
            ^)
                NEW_VAL=${VALUE#*||}
                UPDATED_JSON=$(echo "$UPDATED_JSON" | jq "$KEY_PATH = $NEW_VAL")
                ;;
            -)
                UPDATED_JSON=$(echo "$UPDATED_JSON" | jq "del($KEY_PATH)")
                ;;
        esac
    done
    
    echo "$UPDATED_JSON"
}

function visualize_diff() {
    local DIFF_TEXT="$1"
    

    local ADD_MARKER="\e[32m●\e[0m"    
    local CHANGE_MARKER="\e[33m●\e[0m" 
    local REMOVE_MARKER="\e[31m●\e[0m" 


    IFS=$'\n' read -d '' -r -a DIFF_LINES <<< "$DIFF_TEXT"


    for DIFF_LINE in "${DIFF_LINES[@]}"; do
        local ACTION="${DIFF_LINE:0:1}"
        local JPATH="${DIFF_LINE:1}"
        local KEY_PATH="${JPATH%%"%|#"*}"
        local VALUE="${JPATH#*"%|#"*}"


        READABLE_PATH=$(echo "$KEY_PATH" | sed 's/\./\//g')
        READABLE_PATH=$(echo "$READABLE_PATH" | sed 's/\"//g')
        READABLE_PATH=$(echo "$READABLE_PATH" | sed 's/\[//g; s/\]//g')


        case "$ACTION" in
            +)
                echo -e "${ADD_MARKER} ${READABLE_PATH} was added with value <${VALUE}>"
                ;;
            ^)
                OLD_VAL=${VALUE%%||*}
                NEW_VAL=${VALUE#*||}
                echo -e "${CHANGE_MARKER} ${READABLE_PATH} was changed from <${OLD_VAL}> to <${NEW_VAL}>"
                ;;
            -)
                echo -e "${REMOVE_MARKER} ${READABLE_PATH} was removed"
                ;;
        esac
    done
}

function check_and_compare_json() {
    local OLD_DEF_JSON_FILE=$1
    local NEW_DEF_JSON_FILE=$2
    local OLD_USER_JSON_FILE=$3
    local NEW_USER_JSON_FILE=$4
    local FILE_NAME=$(basename "$OLD_DEF_JSON_FILE")
    echo ""    
    echo "Checking $FILE_NAME"

    if [[ "$FILE_NAME" == *"-genesis.json" ]]; then
        echo "Genesis file accepted as is."
        cp "${NEW_DEF_JSON_FILE}" "${NEW_USER_JSON_FILE}"
        return
    fi

    local OLD_DEF_JSON=$(jq -c '.' "$OLD_DEF_JSON_FILE")
    local NEW_DEF_JSON=$(jq -c '.' "$NEW_DEF_JSON_FILE")
    local OLD_USER_JSON=$(jq -c '.' "$OLD_USER_JSON_FILE")
    local NEW_USER_JSON=$(jq -c '.' "$NEW_USER_JSON_FILE")

    local OLD_DEF_HASH=$(echo "$OLD_DEF_JSON" | md5sum | awk '{ print $1 }')
    local NEW_DEF_HASH=$(echo "$NEW_DEF_JSON" | md5sum | awk '{ print $1 }')

    if [ "$OLD_DEF_HASH" == "$NEW_DEF_HASH" ]; then
        echo "No changes detected."
        return
    fi

    echo "Changes detected, proceeding with comparison."

    DEF_CHANGES=$(compare_json_recursive "$OLD_DEF_JSON" "$NEW_DEF_JSON" "" "")
    if [ -n "$DEF_CHANGES" ]; then
        echo ""
        visualize_diff "$DEF_CHANGES"
        echo -n "applying..."        
        NEW_USER_JSON=$(apply_diff "$DEF_CHANGES" "$NEW_USER_JSON")
        echo  "done!"
    else
        echo ""
    fi

    echo "$NEW_USER_JSON" | jq '.' > tmp.json && mv tmp.json "$NEW_USER_JSON_FILE"
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
            if [ -e "$OLD_USER_CONF_SUBJECT" ]; then
                cp -r "$OLD_USER_CONF_SUBJECT" "$NEW_USER_CONF_SUBJECT"
            else
                cp -r "$NEW_DEF_CONF_SUBJECT" "$NEW_USER_CONF_SUBJECT"
            fi
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


