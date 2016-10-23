#!/bin/bash

if [[ $# < 2 ]]; then
    echo >&2 "Missing arguments"
    exit 1
fi

OS_TYPE="$1"
OS_VERSION="$2"

yum -y makecache
# epel-release is not available on fedora
if [[ $OS_TYPE != "fedora" ]]; then
    yum -y install epel-release
fi

yum -y install openssl nss gnutls net-tools coreutils \
               gnutls-utils expect make beakerlib findutils

EC=0

while read test; do
    echo "Running test: $test"
    echo "--------------------------------------"
    pushd "$(dirname "$test")"
    # Works only for beakerlib tests
    make run
    if [[ $? -ne 0 ]]; then
        EC=1
    fi
    echo -e "\n"
    popd
done <<< "$(find /workspace -type f ! -path "*/Library/*" -name "runtest.sh")"

exit $EC
