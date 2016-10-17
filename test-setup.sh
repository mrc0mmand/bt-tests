#!/bin/bash -x

if [[ -z $1 ]]; then
    echo >&2 "Missing OS version"
    exit 1
fi

OS_VERSION=$1
CONT_NAME="centos-${1}-tests"
CERTGEN_REPO="https://github.com/redhat-qe-security/certgen"
CERTGEN_PATH="utils/openssl/Library/certgen"

# Prepare necessary libraries
TMP_DIR="$(mktemp -d tmp.XXXXX)"
mkdir -p "$CERTGEN_PATH"
git clone "$CERTGEN_REPO" "$TMP_DIR"
ls -la $TMP_DIR
cp -r "$TMP_DIR/certgen" "$CERTGEN_PATH"
ls -la $CERTGEN_PATH

sudo docker run --rm --name "$CONT_NAME" \
                -v $PWD:/workspace:rw \
                centos:centos${OS_VERSION} \
                /bin/bash -c "bash -xe /workspace/test-runner.sh" 
