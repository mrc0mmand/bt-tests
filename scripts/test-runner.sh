#!/bin/bash

echo "DEBUG: $OS_TYPE $OS_VERSION $COMP"


if [[ $# < 2 ]]; then
    echo >&2 "Missing arguments"
    exit 1
fi

OS_TYPE="$1"
OS_VERSION="$2"

echo "travis_fold:start:machine-setup"
yum -y makecache
# epel-release is not available on fedora
if [[ $OS_TYPE != "fedora" ]]; then
    yum -y install epel-release
fi

yum -y install openssl nss gnutls net-tools coreutils gawk \
               gnutls-utils expect make beakerlib findutils

EC=0
EXECUTED=()
FAILED=()

export PATH=${PATH}:/workspace/scripts
export TERM=xterm

echo "travis_fold:end:machine-setup"

for test in $(find /workspace -type f ! -path "*/Library/*" -name "runtest.sh");
do
    echo "travis_fold:start:runtest.sh"
    echo "Running test: $test"
    pushd "$(dirname "$test")"
    if [[ ! -f Makefile ]]; then
        echo >&2 "Missing Makefile"
        EC=1
        continue
    fi
    # Check relevancy
    if ! relevancy.awk -v os_type=$OS_TYPE -v os_ver=$OS_VERSION Makefile; then
        echo "This test is not relevant for current release"
        continue
    fi
    # Install test dependencies
    DEPS="$(awk '
        match($0, /\"Requires:[[:space:]]*(.*)\"/, m) {
            print m[1];
        }' Makefile)"
    if [[ ! -z $DEPS ]]; then
        yum -y install $DEPS
    fi
    # Works only for beakerlib tests
    make run
    if [[ $? -ne 0 ]]; then
        FAILED+=("$test")
        EC=1
    fi
    popd
    EXECUTED+=("$test")
    echo "travis_fold:end:runtest.sh"
done

echo "Executed tests:"
printf '%s\n' "${EXECUTED[@]}"

echo "Failed tests:"
printf '%s\n' "${FAILED[@]}"

exit $EC
