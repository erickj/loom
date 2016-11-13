#!/bin/sh
bin/loom weave fail -t \
	 -l spec/test.loom \
	 -X log_level=info \
	 -H vm-ubuntu-db \
	 -X sshkit_log_level=debug \
	 -X log_device=stderr \
	 -X run_failure_strategy=cowboy 1>&2 < /dev/null
rc=$?

# expect exit code 101 (100 for patterns execution error + 1 failed pattern)
if [ "${rc}" = "101" ]; then
    # runall.sh exits succesfully on this failure because we expect
    # the "fail" pattern to fail
    exit 0
else
    echo "failed with exit code ${rc}"
    exit $rc
fi
