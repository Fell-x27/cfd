#!/bin/bash

function download_file() {
    URL=$1
    FILE_PATH=$2

    echo "Trying to download from $URL"
    wget -q $URL -O $FILE_PATH
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "Error: Unable to download file from $URL"
        return 1
    else
        echo "Success!"
        return 0
    fi
}

function download_and_extract_targz() {
    URL=$1    
    DEST_DIR=$2
    ARCHIVE_DIR=$3
    STRIP_COMPONENTS=$4
    
    if ! [ -z "$STRIP_COMPONENTS" ];then
        STRIP_COMPONENTS="--strip-components=$STRIP_COMPONENTS"
    fi
    
    echo "Trying to download from $URL"
    TEMP_ARCHIVE="$(mktemp).tar.gz"
    wget --progress=bar:force:noscroll $URL -O $TEMP_ARCHIVE

    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "Error: Unable to download archive from $URL"
        return 1
    else
        echo "Success!"
    fi

    echo "Extracting..."
    tar -xf $TEMP_ARCHIVE -C $DEST_DIR $ARCHIVE_DIR $STRIP_COMPONENTS

    EXTRACT_STATUS=$?

    if [ $EXTRACT_STATUS -ne 0 ]; then
        echo "Error: Unable to extract archive $TEMP_ARCHIVE"
        return 1
    else 
        echo "Success!"
    fi

    rm $TEMP_ARCHIVE
    return 0
}
