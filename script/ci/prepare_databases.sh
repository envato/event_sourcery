#!/bin/bash -ex

dropdb event_sourcery_test || echo 0
createdb event_sourcery_test
