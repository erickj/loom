# The Harness script for encoding, checksum'ing and running loom
# patterns.
#
# The point of the harness is to safely encode arbitrary commands as
# base64 strings and execute them in another shell, usually on a
# remote machine over SSH. The flow for running the harness is:
#
# 1. base64 encode an arbitrary shell script, this is the encoded
#    script
# TODO[P0]: this should be a checksum for the original script!!! Check the code.
# 2. get a checksum for the encoded script
# 3. send the encoded script and checksum to a shell in another
#    process (local or remote) to invoke the encoded script via this
#    harness script
#
# Given 2 hosts, [local] and [remote] the process looks like this:
#
#  [local]$ encoded=$(./scripts/harness.sh --print_base64 - <<'EOS'
#  echo my sweet script
#  EOS
#  )
#  [local]$ checksum=$(./scripts/harness --print_checksum $encoded)
#
#  ... SCP harness.sh to some/path on remote ...
#
#  [local]$ ssh user@remote \
#      some/path/harness.sh --run - $checksum <<EOS
#  $encoded
#  EOS
#
# There are 2 different shells that the harness deals with. The
# harness shell, and the command shell. The point being, to isolate
# each environment and be independent of the other.
#
# The harness shell is the shell used to run the harness script (this
# file). Only POSIX features are supported in the harness
# script. Officially, `bash`, `bash --posix`, and `dash` are suported
# via the specs, (see spec/scripts/harness_spec.rb). Unofficially, any
# POSIX compliant shell should work.
#
# The command shell is the shell used by the harness to execute the
# encoded script. By default the command shell is `/bin/sh`. The
# command shell can be whatever you choose by passing an additonal
# parameter to `harness.sh --run`. For example, to run the encoded
# script in dash:
#
#  [local]$ harness.sh --run - $checksum --cmd_shell /bin/dash <<EOS
#  $encoded
#  EOS
#
# To run the harness script in bash POSIX mode and the command script
# in plain old bash, the following will work:
#
#  [local]$ (bash --posix -) <<HARNESS_EOS
#  harness.sh --run - $checksum --cmd_shell /bin/bash <<COMMAND_EOS
#  $encoded
#  COMMAND_EOS
#  HARNESS_EOS
#
# Commands will be recored as they are executed in the record file. By
# default the record file is /dev/null. To use a record file pass the
# record_file argument to --run, e.g.:
#
#  harness.sh --run - $checksum --record_file /opt/loom/cmds <<CMDS...
#

declare -r DEFAULT_COMMAND_SHELL="/bin/sh"
declare -r DEFAULT_RECORD_FILE="/dev/null"

declare -r TRUE=0
declare -r FALSE=1

declare -r SUCCESS=0

declare -r EXIT_INVALID_BASE64=9
declare -r EXIT_BAD_CHECKSUM=8
declare -r EXIT_MISSING_ARG=2
declare -r EXIT_GENERIC=1

exit_with_usage() {
    script=$(basename "$0")
    echo "Usages:"
    echo "   ${script} --check <base64_blob|-> <golden_checksum>"
    echo "   ${script} --run <base64_blob|-> <golden_checksum> \\"
    echo "                   [--cmd_shell shell] \\"
    echo "                   [--record_file record_file]"
    echo "   ${script} --print_checksum <base64_blob|->"
    echo "   ${script} --print_base64 <raw_cmds|->"
    exit $EXIT_GENERIC
}

##
# If $0 equals "-", then consume and return STDIN, otherwise return
# the value.
value_or_stdin() {
    local value="${1}"

    if [ "${value}" = "-" ]; then
        echo "read stdin" 1>&2
        (cat)<&0
    else
        echo "read value arg" 1>&2
        echo -n $value
    fi
}

base64_encode_cmds() {
    local raw_cmds="$1"
    echo $(base64 -w0 <<BASE64_EOF
${raw_cmds}
BASE64_EOF
)
}

validate_base64_blob() {
    local unknown_blob="$1"
    (base64 -d <<BASE64_EOF
${unknown_blob}
BASE64_EOF
) > /dev/null
    if [ ! "$?" -eq 0 ]; then
        exit $EXIT_INVALID_BASE64
    fi
}

validate_arg_is_present() {
    arg="$1"
    msg="$2"
    if [ -z "${arg}" ]; then
        echo "${msg}" 1>&2
        exit $EXIT_MISSING_ARG
    fi
}

print_checksum() {
    local chksum_blob="$1"

    echo "checksum'ing base64 blob: +${chksum_blob}+" 1>&2
    echo $(sha1sum - <<CHECKSUM_EOF | cut -d' ' -f1
${chksum_blob}
CHECKSUM_EOF
)
}

check_cmds() {
    local base64_blob="$1"
    local golden_sha1="$2"
    local actual_sha1=$(print_checksum "${base64_blob}")

    test "${golden_sha1}" = "${actual_sha1}"
}

run_cmds() {
    local base64_blob="$1"
    local cmd_shell="${2:-$DEFAULT_COMMAND_SHELL}"
    local record_file="${3:-$DEFAULT_RECORD_FILE}"
    (
        base64 -d | tee -a ${record_file} | ${cmd_shell} -
    ) <<RUN_EOS
${base64_blob}
RUN_EOS
}

main() {
    set -xv
    local flag="$1"
    local should_run=$FALSE
    shift

    if [ -z "${flag}" ]; then
        exit_with_usage
    fi

    case $flag in
        --print_base64)
            declare -r raw_cmds=$(value_or_stdin "$1")
            declare -r base64_blob=$(base64_encode_cmds "${raw_cmds}")
            validate_base64_blob "${base64_blob}"

            printf $base64_blob
            exit $SUCCESS
            ;;
        --print_checksum)
            declare -r base64_blob=$(value_or_stdin "$1")
            validate_base64_blob "${base64_blob}"

            printf $(print_checksum "${base64_blob}")
            exit $SUCCESS
            ;;
	--check)
            declare -r base64_blob=$(value_or_stdin "$1")
            declare -r golden_sha1="$2"
            shift
            shift
            ;;
	--run)
            should_run=$TRUE
            declare -r base64_blob=$(value_or_stdin "$1")
            declare -r golden_sha1="$2"
            shift
            shift

            while (( "$#" >= 2 )); do
                case "$1" in
                    --cmd_shell)
                        declare -r cmd_shell="$2"
                        shift
                        shift
                        ;;
                    --record_file)
                        declare -r record_file="$2"
                        shift
                        shift
                        ;;
                    *)
                        echo "unknown arg for --run: ${1}" 1>&2
                        exit_with_usage
                        shift
                        ;;
                esac
                shift
            done
            ;;
	*)
            exit_with_usage
	    ;;
    esac

    validate_arg_is_present "${base64_blob}" "missing base64_blob"
    validate_arg_is_present "${golden_sha1}" "missing golden_sha1"
    validate_base64_blob "${base64_blob}"

    if ! (check_cmds "${base64_blob}" "${golden_sha1}"); then
        echo "checksum failed, expected ${golden_sha1}" 1>&2
        exit $EXIT_BAD_CHECKSUM
    fi

    if [ "${should_run}" -eq $TRUE ]; then
        echo "running commands" 1>&2
        run_cmds "${base64_blob}" "${cmd_shell}" "${record_file}"
    fi
}

main "$@"
