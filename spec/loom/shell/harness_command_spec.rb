describe Loom::Shell::HarnessCommand do

  HARNESS = "./scripts/harness.sh"

  # Set debug_script to true in a context to see STDERR debugging.
  let(:debug_script) { false }

  let(:cmd) { 'echo hi there | (echo "from subshell"; cat);' }
  let(:encoded_script) do
    run_harnes_script "--print_base64", :stdin => cmd
  end
  let(:golden_checksum) do
    run_harnes_script "--print_checksum", encoded_script
  end


  def run_harnes_script(cmd, *args, stdin: nil)
    cmd = %Q{./scripts/harness.sh 2>/dev/null #{cmd}}

    heredoc = nil
    if stdin
      heredoc = "<<'EOS'\n#{stdin}\nEOS"
      cmd << " - #{args.join " "} #{heredoc}"
    else
      cmd << " #{args.join " "}"
    end

    %x{#{cmd}}
  end

  describe "scripts/harness.sh parity" do

    subject { Loom::Shell::HarnessCommand.new cmd }

    it "computes a valid script checksum" do
      run_harnes_script "--check", golden_checksum, {
                          :stdin => subject.encoded_script
                        }
      expect($?.exitstatus).to eq 0
    end
  end
end
