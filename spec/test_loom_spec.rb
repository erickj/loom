require 'open3'

describe "spec .loom files" do
  include LoomSpec::LoomInternalsHelper

  LOOM_FILES = Dir.glob "spec/.loom/**/*.loom"

  # Tests disabled until this runs on an overlayfs container
  XFILE_SET = {
    "error_handling.loom" => true,
    "files.loom" => true,
    "pkg.loom" => true,
    "user.loom" => true,
    "vms.loom" => true,
  }

  EXPECTED_EXIT_CODE = {
    # 100 to indicate failing patterns
    # + 3 failed patterns
    # ---
    # 103 expected exit code
    "fail.loom" => 103
  }

  SPEC_TAGS = {
    :integration => true,
    :long => true
  }

  let(:host) { "rp0" }
  let(:patterns) { ref_set.slugs }
  let(:command) { nil }

  let(:executor) { lambda do |*cmd_parts|
      cmd_exec = cmd_parts.join ' '
      output = `#{cmd_exec} 2>&1`
      OpenStruct.new({
        cmd_exec: cmd_exec,
        stdout: output,
        rc: $?.exitstatus,
      })
    end }
  let(:exec_result) { executor.call(*command) }

  context "$ loom inventory", smoke: true do
    let(:command) {[
        "bin/loom inventory",
        "-X loom_search_paths=./spec/.loom"
      ]}

    it "should list all hosts in inventory.yml" do
      result = exec_result

      ["a.host.to.check", "my.other.host"].each do |h|
        expect(result.stdout).to match(/#{h}/), result.to_yaml
      end
      expect(result.rc).to eql 0
    end
  end

  context "$ loom pattern", smoke: true do
    let(:command) {[
        "bin/loom patterns",
        "-l #{LOOM_FILES.join ','}"
      ]}

    it "should list all patterns to stdout" do
      result = exec_result

      # some expected pattern slug namespaces
      ["pkg", "shell", "expectedfailures", "test"].each do |ns|
        expect(result.stdout).to match(/^\s*#{ns}:.+/), result.to_yaml
      end
      expect(result.rc).to eql 0
    end
  end

  context "$ loom weave" do

    # Tests important command line flags
    let(:command) {[
        "bin/loom weave #{patterns.join " "}",
        "-t",
        "-l #{loom_file}",
        "-X log_level=info",
        "-H #{host}",
        "-V",
        "-X sshkit_log_level=warn",
        "-X log_device=stderr",
        "-X run_failure_strategy=cowboy",
        "-F param_facts='from args'"
      ]}

    # bundle exec rspec --tag smoke
    context "test.loom" do
      let(:loom_file) { LOOM_FILES.select { |p| p.match?(/#{subject}/) }.first }
      let(:ref_set) { create_reference_set(path: loom_file) }
      let(:patterns) { [:smoke] }
      let(:host) { "localhost" }

      it "should pass the smoke tests quickly", :smoke => true do
        result = exec_result
        unless result.rc == 0
          puts "loom output:\n#{output}"
        end
        expect(result.rc).to eq(0), result.to_yaml
      end
    end

    # bundle exec rspec --tag integration
    LOOM_FILES.each do |loom_file|
      context File.basename loom_file do
        let(:loom_file) { loom_file }
        let(:ref_set) { create_reference_set(path: loom_file) }

        if XFILE_SET[File.basename(loom_file)]
          xit "should pass all the tests",
          SPEC_TAGS.merge(:file => File.basename(loom_file)) {}
        else
          it "should pass all tests",
          SPEC_TAGS.merge(:file => File.basename(loom_file)) do
            exec = command.join(' ')
            puts <<EOS
            executing command:
              $ #{exec}
EOS
            # TODO pattern match the commands on STDOUT (see comment in
            # .loom/test.loom)
            output = `#{exec}`

            basename = File.basename(loom_file)
            expected_exit_code = EXPECTED_EXIT_CODE[basename] || 0
            expect($?.exitstatus).to eq expected_exit_code
          end
        end
      end
    end
  end
end

# Archived 10/26/2018

# TODO: fix this test to run the runloom.sh script. Currently running
# the loom script in a child process from ruby runs without a
# TTY. This causes the sshkit/net:ssh connection to connect abnormally
# (don't know why). The script does not use ssh keys and instead uses
# password auth to ssh, at which point the script halts waiting for
# input. Running w/ sshkit debugging reveals some of the issue. See
# this stack:

# [I] executing patterns ["fail"] across hosts ["vm-ubuntu-db"]
#   INFO [7befb8a7] Running which facter on vm-ubuntu-db
#  DEBUG [7befb8a7] Command: which facter
# erick@192.168.56.101's password: stty: 'standard input': Inappropriate ioctl for device
# stty: 'standard input': Inappropriate ioctl for device
# stty: 'standard input': Inappropriate ioctl for device

# erick@192.168.56.101's password: stty: 'standard input': Inappropriate ioctl for device
# stty: 'standard input': Inappropriate ioctl for device
# stty: 'standard input': Inappropriate ioctl for device

# erick@192.168.56.101's password: stty: 'standard input': Inappropriate ioctl for device
# stty: 'standard input': Inappropriate ioctl for device
# stty: 'standard input': Inappropriate ioctl for device

# [F] fatal error => #<Net::SSH::AuthenticationFailed: Authentication failed for user erick@192.168.56.101>
# [F] /home/erick/.gem/ruby/gems/net-ssh-3.2.0/lib/net/ssh.rb:249:in `start'
#       /home/erick/.gem/ruby/gems/sshkit-1.11.3/lib/sshkit/backends/connection_pool.rb:59:in `call'
#       /home/erick/.gem/ruby/gems/sshkit-1.11.3/lib/sshkit/backends/connection_pool.rb:59:in `with'
#       /home/erick/.gem/ruby/gems/sshkit-1.11.3/lib/sshkit/backends/netssh.rb:155:in `with_ssh'
#       /home/erick/.gem/ruby/gems/sshkit-1.11.3/lib/sshkit/backends/netssh.rb:108:in `execute_command'
#       /home/erick/.gem/ruby/gems/sshkit-1.11.3/lib/sshkit/backends/abstract.rb:141:in `block in create_command_and_execute'
#       /home/erick/.gem/ruby/gems/sshkit-1.11.3/lib/sshkit/backends/abstract.rb:141:in `tap'
#       /home/erick/.gem/ruby/gems/sshkit-1.11.3/lib/sshkit/backends/abstract.rb:141:in `create_command_and_execute'
#       /home/erick/workspace/src/loom/lib/loom/shell.rb:91:in `execute'
#   xit "executes successfully" do

#     exit_status = nil

#     # https://stackoverflow.com/questions/6338908/ruby-difference-between-exec-system-and-x-or-backticks
#     output = `#{runloom} -F fact_1=1,fact_2=2,fact_3=3`

# #    Open3.popen3(runloom) do |stdin,stdout,stderr,wait_thred|
# #      puts "running #{runloom}"
# #      while line=stderr.gets do
# #        puts line
# #      end
# #
# #      exit_status = wait_thred.value
# #    end

#     puts "exit status: #{$?.exitstatus}"

#     expect($?.exitstatus).to eq 0
#   end
