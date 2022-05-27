#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source ${SCRIPT_DIR}/common.sh

set -e -o pipefail

REPO=$1
OS_NAME=$2
DIST=$3

[ -z "${REPO}" ] && die_var_unset 'REPO'
[ -z "${OS_NAME}" ] && die_var_unset 'OS_NAME'
[ -z "${DIST}" ] && die_var_unset 'DIST'

echo "Repository: ${REPO}"
echo "OS Name: ${OS_NAME}"
echo "Distribution: ${DIST}"

check_mkdir "${CONF_DIR}/${REPO}"

[ -f "${CONF_DIR}/${REPO}/${OS_NAME}.conf" ] || {
  cat <<EOF>${CONF_DIR}/${REPO}/${OS_NAME}.conf
ARCH=(all i386 amd64 arm64 armhf)
COMPONENT=(main)
PASSWORD="$(openssl rand -base64 24)"
EOF
}

source ${CONF_DIR}/${REPO}/${OS_NAME}.conf

for row in ${COMPONENT[*]}; do
  check_mkdir "${INCOMING_DIR}/${REPO}/${OS_NAME}/${DIST}/${row}"
  check_mkdir "${ARCHIVE_DIR}/${REPO}/${OS_NAME}/${DIST}/${row}"
done
