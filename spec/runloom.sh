#!/bin/sh
bin/loom weave uptime facts cd fail test:parent:check_facts test:parent:child:check_facts test:shell:subshell test:shell:sudo test:user:add_users test:user:sudoers test:pkg:update_cache test:pkg:install_httpd test:pkg:install_facter -t \
	 -l spec/test.loom \
	 -X log_level=info \
	 -H vm0.local \
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
