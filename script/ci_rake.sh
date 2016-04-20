#!/bin/bash -ex

echo
echo "--- Bundling"
echo

time ./script/ci/bundle.sh

echo
echo "--- Preparing databases"
echo

time ./script/ci/prepare_databases.sh

echo
echo "+++ Running rake"
echo

time bundle exec rake
