#!/bin/sh
bin/loom weave -A -t \
  -l site.loom \
  -H vm-ubuntu-db \
  -X run_failure_strategy=cowboy
