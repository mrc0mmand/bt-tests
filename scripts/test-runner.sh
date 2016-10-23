#!/bin/bash

yum -y makecache
# TODO: epel-release is not in fedora
yum -y install epel-release openssl nss gnutls net-tools coreutils \
               gnutls-utils expect
yum -y install beakerlib

EC=0

while read test; do
    TESTPATH="/workspace/$test"
    echo "Running test: $test"
    echo "--------------------------------------"
    chmod +x "$TESTPATH"
    pushd "$(dirname "$TESTPATH")"
    "$TESTPATH"
    if [[ $? -ne 0 ]]; then
        EC=1
    fi
    echo -e "\n"
    popd
done <<< "$(find . -type f -name "runtest.sh")"

exit $EC
