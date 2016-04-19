#!/bin/bash -ex

dropdb fountainhead_test || echo 0
createdb fountainhead_test
