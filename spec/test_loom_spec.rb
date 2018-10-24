require 'open3'

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

xdescribe "spec/test.loom file" do

  let(:runloom) { File.join File.dirname(__FILE__), 'runloom.sh' }

  it "executes successfully" do
    exit_status = nil
    `#{runloom}`
#    Open3.popen3(runloom) do |stdin,stdout,stderr,wait_thred|
#      puts "running #{runloom}"
#      while line=stderr.gets do
#        puts line
#      end
#
#      exit_status = wait_thred.value
#    end

    puts "exit status: #{$?.exitstatus}"

    expect($?.exitstatus).to eq 0
  end
end
