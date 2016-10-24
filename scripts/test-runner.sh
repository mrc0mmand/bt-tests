#!/bin/bash

set +x

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
SKIP=0
INDEX=0
EXECUTED=()
FAILED=()
SKIPPED=()

export PATH=${PATH}:/workspace/scripts

echo "travis_fold:end:machine-setup"

for test in $(find /workspace -type f ! -path "*/Library/*" -name "runtest.sh");
do
    echo "travis_fold:start:runtest.sh.$INDEX"
    SKIP=0
    ((INDEX++))

    echo "Running test: $test"
    pushd "$(dirname "$test")"
    if [[ ! -f Makefile ]]; then
        echo >&2 "Missing Makefile"
        EC=1
        SKIP=1
    fi
    if [[ $SKIP -eq 0 ]]; then
        # Check relevancy
        if relevancy.awk -v os_type=$OS_TYPE -v os_ver=$OS_VERSION Makefile; then
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
        else
            echo "This test is not relevant for current release"
            SKIP=1
        fi
    fi
    popd

    if [[ $SKIP -eq 0 ]]; then
        EXECUTED+=("$test")
    else
        SKIPPED+=("$test")
    fi
    echo "travis_fold:end:runtest.sh.$INDEX"
done

echo "RESULTS:"

echo "Executed tests:"
printf '%s\n' "${EXECUTED[@]}"

echo "Skipped tests:"
printf '%s\n' "${SKIPPED[@]}"

echo "Failed tests:"
printf '%s\n' "${FAILED[@]}"

exit $EC
