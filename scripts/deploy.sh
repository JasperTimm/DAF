#!/bin/bash
set -e
set -o pipefail
set -x

npx truffle migrate --network dafnet --f 2
aws s3 sync build s3://dafapp/build
