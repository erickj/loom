module Loom::Shell
  class CmdResult
    def initialize(command, stdout, stderr, exit_status, is_test, shell)
      @command = command
      @stdout = stdout
      @stderr = stderr
      @exit_status = exit_status
      @is_test = is_test
      @time = Time.now
      @shell = shell
    end

    attr_reader :command, :stdout, :stderr, :exit_status, :time, :is_test

    def success?
      @exit_status == 0
    end

    def pipe(*cmd, fd: :stdout)
      puts "stdout >>> " + @stdout.inspect
      @shell.pipe [:"/bin/echo", "-e", @stdout], [*cmd]
    end

    def self.create_from_sshkit_command(cmd, is_test, shell)
      CmdResult.new cmd.command,
                        cmd.full_stdout,
                        cmd.full_stderr,
                        cmd.exit_status,
                        is_test,
                        shell
    end
  end
end
