#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source ${SCRIPT_DIR}/common.sh

set -e -o pipefail

REPO=$1
OS_NAME=$2
DIST=$3
REPO_COMPONENT=$4

[ -z "${REPO}" ] && die_var_unset 'REPO'
[ -z "${OS_NAME}" ] && die_var_unset 'OS_NAME'
[ -z "${DIST}" ] && die_var_unset 'DIST'
[ -z "${REPO_COMPONENT}" ] && die_var_unset 'REPO_COMPONENT'

TMP_DIR=$(mktemp -d)

function cleanup {
  [ -d "${TMP_DIR}" ] && {
    rm -Rf ${TMP_DIR}
  }
}

trap cleanup EXIT

[ -f "${CONF_DIR}/${REPO}/${OS_NAME}.conf" ] && {
  source ${CONF_DIR}/${REPO}/${OS_NAME}.conf
}

[ -z "${ARCH}" ] && die_var_unset 'ARCH'
[ -z "${PASSWORD}" ] && die_var_unset 'PASSWORD'

repo_root_dir="${PUBLIC_DIR}/${REPO}/${OS_NAME}"
repo_incoming="${INCOMING_DIR}/${REPO}/${OS_NAME}/${DIST}/${REPO_COMPONENT}"
repo_pkg_dir="${repo_root_dir}/pool/${DIST}/${REPO_COMPONENT}"
repo_archive="${ARCHIVE_DIR}/${REPO}/${OS_NAME}/${DIST}/${REPO_COMPONENT}"

check_mkdir "${repo_incoming}"
check_mkdir "${repo_pkg_dir}"
check_mkdir "${repo_archive}"

for repo_arch in ${ARCH[*]}; do
  for line in $(find ${repo_incoming} -type f -name "*_${repo_arch}.deb"); do
    filename=$(basename -- "$line")
    pkgname=$(echo ${filename} | awk -F'_' '{print $1}')

    firstCharacter=${pkgname:0:1}
    [ "${pkgname:0:3}" == "lib" ] && {
      firstCharacter="${pkgname:0:4}"
    }

    dst_path="${repo_pkg_dir}/${firstCharacter}/${pkgname}"
    check_mkdir "${dst_path}"

    [ -f "${dst_path}/${filename}" ] && rm ${dst_path}/${filename}

    mv ${line} ${dst_path}/

    for pkg in $(ls -A ${dst_path} | head -n -${KEEP_LAST}); do
      check_mkdir "${repo_archive}/${pkgname}"
      mv ${dst_path}/${pkg} ${repo_archive}/${pkgname}/
    done
  done
done

find ${repo_archive} -type d -empty -delete

cat <<EOF>${TMP_DIR}/aptftp.conf
APT::FTPArchive::DoByHash true;
APT::FTPArchive::Release {
  Origin "${VENDOR}";
  Label "${VENDOR} APT Repository for ${REPO}";
  Suite "stable";
  Architectures "${ARCH[*]}";
  Components "${COMPONENT}";
  Codename "${DIST}";
  MD5 false;
}
EOF

meta_dir="${repo_root_dir}/dists/${DIST}/${REPO_COMPONENT}"

[ -d "${meta_dir}" ] && {
  rm -Rf ${meta_dir}
  check_mkdir "${meta_dir}"
}

cd ${repo_root_dir}

for repo_arch in ${ARCH[*]}; do
  check_mkdir "${meta_dir}/binary-${repo_arch}"

  apt-ftparchive --arch ${repo_arch} packages pool/${DIST}/${REPO_COMPONENT} \
    | tee ${meta_dir}/binary-${repo_arch}/Packages \
    | gzip -c -9 > ${meta_dir}/binary-${repo_arch}/Packages.gz

  apt-ftparchive contents pool/${DIST}/${REPO_COMPONENT} \
    | tee dists/${DIST}/${REPO_COMPONENT}/Contents-${repo_arch} \
    | gzip -c -9 > dists/${DIST}/${REPO_COMPONENT}/Contents-${repo_arch}.gz

  apt-ftparchive release dists/${DIST}/${REPO_COMPONENT}/binary-${repo_arch} \
    | tee dists/${DIST}/${REPO_COMPONENT}/binary-${repo_arch}/Release \
    | gzip -c -9 > dists/${DIST}/${REPO_COMPONENT}/binary-${repo_arch}/Release.gz
done

apt-ftparchive release -c ${TMP_DIR}/aptftp.conf dists/${DIST} \
  | tee dists/${DIST}/Release \
  | gzip -c -9 > dists/${DIST}/Release.gz


# Sign repository

GPGCMD="gpg --homedir ${TMP_DIR} --no-default-keyring --keyring ${TMP_DIR}/trustedkeys.gpg"

[ -f "${CONF_DIR}/${REPO}/${OS_NAME}_private.gpg" ] || {
  ${GPGCMD} --batch --passphrase "${PASSWORD}" --quick-gen-key "[MeroLabs] Sign key for ${REPO}-${OS_NAME}" default default never
  ${GPGCMD} --pinentry-mode loopback --passphrase "${PASSWORD}" --export-secret-keys --armor --output ${CONF_DIR}/${REPO}/${OS_NAME}_private.gpg
}

cat ${CONF_DIR}/${REPO}/${OS_NAME}_private.gpg | ${GPGCMD} --pinentry-mode loopback --passphrase "${PASSWORD}" --import 2> /dev/null

${GPGCMD} --yes --pinentry-mode loopback --passphrase ${PASSWORD} -bao dists/${DIST}/Release.gpg dists/${DIST}/Release
${GPGCMD} --yes --clear-sign --output dists/${DIST}/InRelease dists/${DIST}/Release

[ -f "sign-key.gpg" ] || {
  ${GPGCMD} --pinentry-mode loopback --passphrase "${PASSWORD}" --export --output sign-key.gpg
}

[ -f "sign-key.gpg.txt" ] || {
  ${GPGCMD} --pinentry-mode loopback --passphrase "${PASSWORD}" --export --armor --output sign-key.gpg.txt
}
