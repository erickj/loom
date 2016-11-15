#!/bin/sh

spec_file="spec/test.loom"
all_patterns=$(bin/loom patterns --print \
			-t \
			-l ${spec_file})

bin/loom weave ${all_patterns} \
	 -t \
	 -l ${spec_file} \
	 -X log_level=info \
	 -H vm0.local \
	 -X sshkit_log_level=warn \
	 -X log_device=stderr \
	 -X run_failure_strategy=cowboy
rc=$?

# expect exit code 102 (100 for patterns execution error + 2 failed pattern)
if [ "${rc}" = "102" ]; then
    # runall.sh exits succesfully on this failure because we expect
    # the "fail" patterns to fail
    exit 0
else
    echo "failed with exit code ${rc}"
    exit $rc
fi
