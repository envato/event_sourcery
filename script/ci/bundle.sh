#!/bin/bash -ex

bundle check || bundle --binstubs --path vendor/bundle
