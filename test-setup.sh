#!/bin/bash -x

if [[ $# < 3 ]]; then
    echo >&2 "Missing arguments"
    exit 1
fi

COMPONENT="$1"
OS_TYPE="$2"
OS_VERSION="$3"
CONT_NAME="centos-${1}-tests"
CERTGEN_REPO="https://github.com/redhat-qe-security/certgen"
CERTGEN_PATH="openssl/Library/certgen"

# Prepare necessary libraries
TMP_DIR="$(mktemp -d tmp.XXXXX)"
mkdir -p "$CERTGEN_PATH"
git clone "$CERTGEN_REPO" "$TMP_DIR"
ls -la $TMP_DIR
cp -a "$TMP_DIR/certgen/." "$CERTGEN_PATH/"
ls -la $CERTGEN_PATH

sudo docker run --rm --name "$CONT_NAME" \
                -v $PWD:/workspace:rw \
                ${OS_TYPE}:${OS_TYPE}${OS_VERSION} \
                /bin/bash -c "bash -xe /workspace/test-runner.sh"
