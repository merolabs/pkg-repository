#!/bin/bash

function die_var_unset {
  echo "ERROR: Variable '$1' is required to be set."
  exit 1
}

function check_mkdir {
  [ -d "$1" ] || mkdir -p $1
}

[ -z "${SCRIPT_DIR}" ] && {
  export SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
}

HOME_DIR=$(cd -- ${SCRIPT_DIR} &> /dev/null && cd -- .. && pwd )

KEEP_LAST=10
VENDOR="MeroLabs"

INCOMING_DIR="${HOME_DIR}/incoming"
PUBLIC_DIR="${HOME_DIR}/public"
CONF_DIR="${HOME_DIR}/conf"
ARCHIVE_DIR="${HOME_DIR}/archive"

[ -f "${CONF_DIR}/config.conf" ] && source ${CONF_DIR}/config.conf

check_mkdir "${INCOMING_DIR}"
check_mkdir "${PUBLIC_DIR}"
check_mkdir "${CONF_DIR}"
check_mkdir "${ARCHIVE_DIR}"
