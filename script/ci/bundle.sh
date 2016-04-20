#!/bin/bash -ex

BUNDLE_PATH=vendor/bundle
bundle check --path $BUNDLE_PATH || bundle --binstubs --path $BUNDLE_PATH
