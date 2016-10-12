#!/bin/bash

yum -y makecache
# TODO: epel-release is not in fedora
yum -y install epel-release openssl nss gnutls net-tools coreutils gnutls-utils
yum -y install beakerlib

EC=0
TESTS=(
    "example/runtest.sh"
)

for test in ${TESTS[@]}; do
    echo "Running test: $test"
    echo "--------------------------------------"
    chmod +x $test
    TERM=dumb ./$test
    if [[ $? -ne 0 ]]; then
        EC=1
    fi
    echo -e "\n"
done

return $EC