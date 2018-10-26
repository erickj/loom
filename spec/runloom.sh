#!/bin/sh
pattern_file="${1}"
if [ "${pattern_file}" = "" ]; then
    echo "Usage: $0 <spec/path/to/.loom/file>"
    exit 1
fi

spec_file="spec/${pattern_file}"
all_patterns=$(bin/loom patterns --print \
			-t \
			-l ${spec_file})

shift
addl_args="${@}"

# TODO: Fix this to bring up a local container via
# systemd-nspawn. Either an alpine host, or something else really
# cheap and fast. NO DOCKER. Will rkt ever be a reasonable option?
bin/loom weave ${all_patterns} \
	 -t \
	 -l ${spec_file} \
	 -X log_level=info \
	 -H rp0 \
         -V \
	 -X sshkit_log_level=warn \
	 -X log_device=stderr \
	 -X run_failure_strategy=cowboy \
	 ${addl_args}
