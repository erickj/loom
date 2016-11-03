require "sshkit"

module Loom
  class Shell

    VerifyError = Class.new Loom::LoomError

    def initialize(sshkit_backend)
      @sshkit_backend = sshkit_backend
      @session = ShellSession.new
      @local_shell = nil
    end

    attr_reader :session

    def local
      @local_shell ||= LocalShell.new
    end

    def verify(check)
      raise VerifyError, check unless @sshkit_backend.test check
    end

    def method_missing(method, *args, &block)
      execute method, *args
    end

    def execute(*args, &block)
      Loom.log.debug { "$ #{args}" }

      # This is a big hack to get access to the SSHKit command object
      # and avoid the automatic errors thrown on non-zero error codes
      sshkit_cmd = @sshkit_backend.send(
        :create_command_and_execute,
        args,
        :raise_on_non_zero_exit => false)

      @session << CommandResult.create_from_sshkit_command(sshkit_cmd)

      Loom.log.debug @session.last.stdout unless @session.last.stdout.empty?
      Loom.log.debug @session.last.stderr unless @session.last.stderr.empty?
    end
    alias_method :capture, :execute

    [:test, :within, :as].each do |method|
      define_method method do |*args, &block|
        @sshkit_backend.send method, *args, &block
      end
    end
  end

  class ShellSession
    def initialize
      @command_results = []
      @success = true
    end

    attr_reader :command_results

    def success?
      @success
    end

    def last
      @command_results.last
    end

    def <<(command_result)
      @command_results << command_result
      @success &&= command_result.success?
    end
  end

  class CommandResult
    def initialize(command, stdout, stderr, exit_status)
      @command = command
      @stdout = stdout
      @stderr = stderr
      @exit_status = exit_status
    end

    attr_reader :command, :stdout, :stderr, :exit_status

    def success?
      @exit_status == 0
    end

    def self.create_from_sshkit_command(cmd)
      return CommandResult.new cmd.command, cmd.full_stdout, cmd.full_stderr, cmd.exit_status
    end
  end

  class LocalShell < Shell
    def initialize
      super SSHKit::Backend::Local.new
    end

    def local
      raise 'already in a local shell'
    end
  end
end
