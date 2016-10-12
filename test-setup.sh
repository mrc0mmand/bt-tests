#!/bin/bash

if [[ -z $1 ]]; then
    echo >&2 "Missing OS version"
    exit 1
fi

OS_VERSION=$1
CONT_NAME="centos-7-tests"

sudo docker run --rm --name "$CONT_NAME" \
                -v $PWD:/workspace:rw \
                centos:centos${OS_VERSION} \
                /bin/bash -c "bash -xe /workspace/test-runner.sh" 
