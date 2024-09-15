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
        if [ "$(echo "$DESIRED_SF_VERSION" | awk -F'-' '{print NF-1}')" -eq 1 ]; then
            DESIRED_SF_VERSION_BASE=$(echo "$DESIRED_SF_VERSION" | awk -F'-' '{print $1}')
            DESIRED_SF_VERSION_SUFFIX=$(echo "$DESIRED_SF_VERSION" | awk -F'-' '{print "-"$2}')
        else
            DESIRED_SF_VERSION_BASE="$DESIRED_SF_VERSION"
            DESIRED_SF_VERSION_SUFFIX=""
        fi


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
                echo "$SF_NAME ver: $DESIRED_SF_VERSION not found"
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
	    if [ -e "$OLD_USER_CONF_SUBJECT" ] && [[ "$OLD_USER_CONF_SUBJECT" == *.json ]] && [[ "$OLD_USER_CONF_SUBJECT" != *-genesis.json ]]; then
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
        check-dependencies $(echo "$REQUIRED_SOFTWARE_LIST" | tr '\n' ' ')

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


