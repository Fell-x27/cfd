#!/bin/bash

function check-sync {
    echo "***************************************" 1>&2
    wrap-cli-command run-check-sync
}
