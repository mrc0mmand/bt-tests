#!/bin/bash

yum -y makecache
# TODO: epel-release is not in fedora
yum -y install epel-release openssl nss gnutls net-tools coreutils \
               gnutls-utils expect
yum -y install beakerlib

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
done <<< "$(find /workspace -type f -name "runtest.sh")"

exit $EC
