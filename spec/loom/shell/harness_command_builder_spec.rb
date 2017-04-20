describe Loom::Shell::HarnessCommandBuilder do

  let(:cmd) do
    <<CMD
cd /tmp
pwd
CMD
  end
  let(:harness_command) { Loom::Shell::HarnessCommand.new cmd }

  subject { Loom::Shell::HarnessCommandBuilder.new harness_command }

  context "#run" do
    it "builds run commands for the harness" do
      expected_cmd = [
        "./scripts/harness.sh",
        "--run 2>/dev/null",
        "-",
        harness_command.checksum,
        "--cmd_shell /bin/dash",
        "<<'[\\w]+'\n"
      ].join " "

      expected_cmd << harness_command.encoded_script + "\n[\\w]+"

      expect(subject.run_cmd).to match /^#{expected_cmd}/
    end

    it "is shell executable" do
      result = %x{#{subject.run_cmd}}
      expect(result).to eq "/tmp\n"
      expect($?.exitstatus).to be 0
    end
  end
end
