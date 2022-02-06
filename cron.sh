#!/bin/bash

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
source ${SCRIPT_DIR}/common.sh

set -e -o pipefail

for repo in $(ls -A ${CONF_DIR}/); do
  for os_name_conf in $(ls ${CONF_DIR}/${repo}/*.conf); do
    os_name=$(basename -- ${os_name_conf%.*})

    for dist in $(ls -A ${INCOMING_DIR}/${repo}/${os_name}/); do
      check_mkdir "${INCOMING_DIR}/${repo}/${os_name}/${dist}"
      source ${CONF_DIR}/${repo}/${os_name}.conf

      for row in ${COMPONENT[*]}; do
        check_mkdir "${INCOMING_DIR}/${repo}/${os_name}/${dist}/${row}"

        if [ "x$(ls -A ${INCOMING_DIR}/${repo}/${os_name}/${dist}/${row}/ | grep '.deb' | wc -l)" != "x0" ]; then
	  [ -d "${SCRIPT_DIR}/hook-before-build.d/" ] && {
            export REPOSITORY=${repo}
	    export OS_NAME=${os_name}
	    export DISTRIBUTIVE=${dist}
	    export COMPONENT=${row}
	    export CONFIG_DIR=${CONF_DIR}
	    run-parts --regex '.*sh$' ${SCRIPT_DIR}/hook-before-build.d/
	  }

          ${SCRIPT_DIR}/build.sh ${repo} ${os_name} ${dist} ${row}

	  [ -d "${SCRIPT_DIR}/hook-after-build.d/" ] && {
            export REPOSITORY=${repo}
	    export OS_NAME=${os_name}
	    export DISTRIBUTIVE=${dist}
	    export COMPONENT=${row}
	    export CONFIG_DIR=${CONF_DIR}
	    run-parts --regex '.*sh$' ${SCRIPT_DIR}/hook-after-build.d/
	  }
        fi
      done
    done
  done
done
