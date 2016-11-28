require 'base64'
require 'tmpdir'

describe 'loom harness script' do

  HARNESS = "./scripts/harness.sh"

  # Set debug_script to true in a context to see STDERR debugging.
  let(:debug_script) { false }

  def run_script(cmd, *args, stdin: nil, harness_shell: :bash)
    stderr_redirect = debug_script ? "" : "2>/dev/null"
    cmd = if stdin
            stdin = stdin.rstrip + "\n"
            heredoc = "<<'SH_EOS'\n#{stdin}\nSH_EOS"
            "#{HARNESS} #{cmd} - #{args.join " "} #{heredoc}"
          else
            "#{HARNESS} #{cmd} #{args.join " "}"
          end

    harness_cmd = "(#{harness_shell} -) #{stderr_redirect} " +
                  "<<'HARNESS_EOS'\n#{cmd}\nHARNESS_EOS"
    if debug_script
      puts "[harness-cmd]$ #{harness_cmd}"
    end

    %x{#{harness_cmd}}
  end

  let(:cmd) { 'echo hi there | (echo "from subshell"; cat);' }
  let(:quoted_cmd) { "'#{cmd}'" }

  # TODO: This is actually the base64 of `cmd` + a trailing newline. I'm
  # not sure whether it should be trimmed first or not.
  let(:base64) do
    "ZWNobyBoaSB0aGVyZSB8IChlY2hvICJmcm9tIHN1YnNoZWxsIjsgY2F0KTsK"
  end

  # TODO: This is actually the checksum of `base64` + a trailing newline. I'm
  # not sure whether it should be trimmed first or not.
  let(:base64_checksum) { "18e75ac603d7cf76db5a841157a3871c5d53f217" }
  let(:expected_output) do
    <<EOS
from subshell
hi there
EOS
  end

  context "--print_base64" do

    it "encodes commands from args" do
      result = run_script :"--print_base64", quoted_cmd
      expect(result).to eq base64
      expect($?.exitstatus).to be 0
    end

    it "encodes commands from STDIN" do
      result = run_script :"--print_base64", :stdin => cmd
      expect(result).to eq base64
      expect($?.exitstatus).to be 0
    end

    context "multiline strings" do
      it "encodes newlines" do
        cmd = <<EOS
cd /tmp
pwd
EOS
        result = run_script :"--print_base64", :stdin => cmd
        expect(result).to eq "Y2QgL3RtcApwd2QK"
        expect(Base64.decode64 result).to eq cmd
      end
    end

    context "trailing whitespace" do

      it "ignores trailing newlines" do
        cmd = "pwd"

        3.times do |i|
          append_str = "\n" * i

          nl_cmd_string = cmd + append_str
          stdin_result = run_script :"--print_base64", :stdin => nl_cmd_string
          argv_result = run_script :"--print_base64", "\"#{nl_cmd_string}\""

          expect(stdin_result).to eq "cHdkCg=="
          expect(argv_result).to eq "cHdkCg=="

          expect(Base64.decode64 argv_result).to eq "pwd\n"
        end
      end
    end
  end

  context "--print_checksum" do

    it "fails if arg is not a base64 blob" do
      result = run_script :"--print_checksum", :stdin => "this is not base64"
      expect($?.exitstatus).to eq 9
    end

    it "prints the sha1 checksum from args" do
      result = run_script :"--print_checksum", base64
      expect(result).to eq base64_checksum
      expect($?.exitstatus).to eq 0
    end

    it "prints the sha1 checksum from STDIN" do
      result = run_script :"--print_checksum", :stdin => base64
      expect(result).to eq base64_checksum
      expect($?.exitstatus).to eq 0
    end

    it "is resilient to trailing whitespace" do
      result1 = run_script :"--print_checksum", base64 + "\n\n"
      expect(result1).to eq base64_checksum
      expect($?.exitstatus).to eq 0

      result2 = run_script :"--print_checksum", :stdin => base64 + "\n\n\n"
      expect(result2).to eq base64_checksum
      expect($?.exitstatus).to eq 0
    end
  end

  context "--check" do

    context "errors" do

      it "if less than 2 args are passed" do
        result = run_script :"--check", "only1arg"
        expect($?.exitstatus).to eq 2

        result = run_script :"--check"
        expect($?.exitstatus).to eq 2
      end

      it "fails for a invalid base64" do
        result = run_script :"--check", "not-base-64", base64_checksum
        expect($?.exitstatus).to eq 9
      end

      it "fails for a bad checksum" do
        result = run_script :"--check", base64, "not-a-checksum"
        expect($?.exitstatus).to eq 8
      end
    end

    context "from args" do

      it "succeeds if the sha1 checksum matches" do
        result = run_script :"--check", base64, base64_checksum
        expect($?.exitstatus).to eq 0
      end
    end
  end

  context "--run" do

    context "errors" do

      it "if less than 2 args are passed" do
        result = run_script :"--run", "only1arg"
        expect($?.exitstatus).to eq 2

        result = run_script :"--run"
        expect($?.exitstatus).to eq 2
      end

      it "fails for a invalid base64" do
        result = run_script :"--run", "not-base-64", base64_checksum
        expect($?.exitstatus).to eq 9
      end

      it "fails for a bad checksum" do
        result = run_script :"--run", base64, "not-a-checksum"
        expect($?.exitstatus).to eq 8
      end
    end

    context "record file" do

      let(:record_file) { "/tmp/harness.cmds" }

      after(:example) do
        File.delete record_file
      end

      it "stores the executed command history" do
        result = run_script :"--run", base64, base64_checksum,
            "--record_file #{record_file}"
        expect(result).to eq expected_output
        expect(File.read(record_file).strip).to eq cmd
      end
    end

    context "runs valid commands" do

      it "from args" do
        result = run_script :"--run", base64, base64_checksum
        expect(result).to eq expected_output
        expect($?.exitstatus).to eq 0
      end

      it "from STDIN" do
        result = run_script :"--run", base64_checksum, :stdin => base64
        expect(result).to eq expected_output
        expect($?.exitstatus).to eq 0
      end
    end

    context "runs in harness shell" do

      it "bash" do
        result = run_script :"--run", base64_checksum, {
          :stdin => base64,
          :harness_shell => "bash"
        }
        expect(result).to eq expected_output
        expect($?.exitstatus).to eq 0
      end

      it "bash --posix" do
        result = run_script :"--run", base64_checksum, {
          :stdin => base64,
          :harness_shell => "bash --posix"
        }
        expect(result).to eq expected_output
        expect($?.exitstatus).to eq 0
      end

      context "dash" do

        it "from args" do
          result = run_script :"--run", base64, base64_checksum, {
            :harness_shell => "/bin/dash"
          }
          expect(result).to eq expected_output
          expect($?.exitstatus).to eq 0
        end

        it "from STDIN" do
          result = run_script :"--run", base64_checksum, {
            :stdin => base64,
            :harness_shell => "/bin/dash"
          }
          expect(result).to eq expected_output
          expect($?.exitstatus).to eq 0
        end
      end
    end

    context "run in command shell" do

      let(:cmd) do
        <<SH_EOS
# The cmd_shell Test
echo $0

# CD Test
cd /tmp
pwd

# The subshell tests
echo "piped to cat" | (
        echo from a subshell
        cat
)
(
        exec 2>&1
        echo "out to err and back to out" 1>&2
)

# The sudo test
sudo -u $(whoami) whoami

# Variable expansion
foo=bar
echo "I am FOO: ${foo}"

# Subshell variable expansion
(
        echo "I am subshell FOO: ${foo}"
        foo=baz
        echo "I am subshell FOO2: ${foo}"
)

# The ulimit test
tmp_file=$(mktemp)
$(
        ulimit -f 0
        echo "this will blow up w/ signal SIGXFSZ" > $tmp_file
)
echo $? # expect exit 153 (signal 25 + 128), SIGXFSZ
rm $tmp_file

SH_EOS
      end

      let(:whoami) { %x{whoami}.strip }
      let(:expected_output) do
        <<EOS
%s
/tmp
from a subshell
piped to cat
out to err and back to out
#{whoami}
I am FOO: bar
I am subshell FOO: bar
I am subshell FOO2: baz
153
EOS
      end

      let(:base64) { run_script :"--print_base64", :stdin => cmd }
      let(:base64_checksum) { run_script :"--print_checksum", :stdin => base64 }

      context "bash" do

        it "from STDIN" do
          result = run_script :"--run", base64_checksum,
              "--cmd_shell /bin/bash", :stdin => base64
          expect($?.exitstatus).to eq 0

          expected_output_for_shell = expected_output % "/bin/bash"
          expect(result).to eq expected_output_for_shell
        end
      end

      context "bash --posix" do

        it "from STDIN" do
          result = run_script :"--run", base64_checksum,
              "--cmd_shell '/bin/bash --posix'", :stdin => base64
          expect($?.exitstatus).to eq 0

          expected_output_for_shell = expected_output % "/bin/bash"
          expect(result).to eq expected_output_for_shell
        end
      end

      context "dash" do

        it "from STDIN" do
          result = run_script :"--run", base64_checksum,
              "--cmd_shell /bin/dash", :stdin => base64
          expect($?.exitstatus).to eq 0

          expected_output_for_shell = expected_output % "/bin/dash"
          expect(result).to eq expected_output_for_shell
        end
      end
    end
  end

  context "usage error" do

    it "prints a usage message" do
      result = run_script nil
      expect(result).to match /^Usages:.*/i
      expect($?.exitstatus).to be 1
    end
  end
end
