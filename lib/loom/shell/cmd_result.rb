module Loom::Shell
  class CmdResult
    def initialize(command, stdout, stderr, exit_status, is_test)
      @command = command
      @stdout = stdout
      @stderr = stderr
      @exit_status = exit_status
      @is_test = is_test
      @time = Time.now
    end

    attr_reader :command, :stdout, :stderr, :exit_status, :time, :is_test

    def success?
      @exit_status == 0
    end

    def self.create_from_sshkit_command(cmd, is_test)
      CmdResult.new cmd.command,
                        cmd.full_stdout,
                        cmd.full_stderr,
                        cmd.exit_status,
                        is_test
    end
  end
end
