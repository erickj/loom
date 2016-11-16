require "forwardable"
require "sshkit"

module Loom

  # TODO: Redefine Shell to be a module, and rename/move ShellApi =>
  # Shell::Api, CommandResult, ShellSession => Shell::Session,
  # LocalShell into the module. Think of a more descriptive name for
  # what is now Shell.. Shell::Core maybe? (that kind of sucks).
  class Shell

    VerifyError = Class.new Loom::LoomError

    def initialize(mod_loader, sshkit_backend, dry_run=false)
      @dry_run = dry_run
      @mod_loader = mod_loader
      @sshkit_backend = sshkit_backend

      @session = ShellSession.new
      @shell_api = ShellApi.new self

      @cmd_wrappers = []
      @sudo_users = []
      @sudo_dir = nil
    end

    attr_reader :session, :shell_api, :mod_loader

    def local
      @local ||= LocalShell.new @mod_loader, @session, @dry_run
    end

    def test(*cmd, check: :exit_status)
      # TODO: This smells like a hack. I can't rely on Command#is_success?  here
      # (returned from execute) because I'm overriding it with :is_test =>
      # true. Fix Command#is_success? to not be a lie.. that is a lazy hack for
      # result reporting (I think the fix & feature) is to define Command
      # objects and declare style of reporting & error code handling it
      # has. Commands can be defined to ignore errors and just return their
      # results.
      execute *cmd, :is_test => true

      case check
      when :exit_status
        @session.last.exit_status == 0
      when :stderr
        @session.last.stderr.empty?
      else
        raise "unknown test check => #{check}"
      end
    end

    def verify(*check)
      raise VerifyError, check unless test *check
    end

    def verify_which(command)
      verify :which, command
    end

    def wrap(wrapper, should_quote: true, &block)
      raise "missing block for +wrap+" unless block_given?

      @cmd_wrappers <<  CmdWrapperSpec.new(wrapper, should_quote)
      begin
        yield
      ensure
        @cmd_wrappers.pop
      end
    end

    def sudo(user=nil, *args, &block)
      user ||= :root
      Loom.log.debug1(self) { "sudo => #{user} #{args} #{block}" }

      is_new_sudoer = @sudo_users.last.to_sym != user.to_sym rescue true

      @sudo_dir = capture :pwd
      @sudo_users << user if is_new_sudoer

      begin
        execute *args unless args.empty?
        yield if block_given?
      ensure
        @sudo_users.pop if is_new_sudoer
        @sudo_dir = nil
      end
    end

    def cd(path, &block)
      Loom.log.debug1(self) { "cd => #{path} #{block}" }
      @sshkit_backend.within path, &block
    end

    def capture(*args)
      result = execute *args
      result ? @session.last.stdout.strip : nil
    end

    def execute(*args, is_test: false)
      cmd = create_command args
      Loom.log.debug { "exec => #{cmd}" }

      if @dry_run
        Loom.log.warn "dry-run only: %s" % cmd
        quote_escaped_cmd = %Q[#{cmd}]
        cmd = "echo \"#{quote_escaped_cmd}\""
      end

      # This is a big hack to get access to the SSHKit command object
      # and avoid the automatic errors thrown on non-zero error codes
      sshkit_cmd = @sshkit_backend.send(
        :create_command_and_execute,
        cmd,
        :raise_on_non_zero_exit => false)

      @session << CommandResult.create_from_sshkit_command(sshkit_cmd, is_test)

      Loom.log.debug @session.last.stdout unless @session.last.stdout.empty?
      Loom.log.debug @session.last.stderr unless @session.last.stderr.empty?

      @session.last.success?
    end
    alias_method :exec, :execute

    private
    def create_command(*args)
      cmd = args.flatten.map(&:to_s).join " "

      # Useful for timing a set of commands, or timeout... anytime you want to
      # prefix a group of commands.
      cmd = @cmd_wrappers.reduce(cmd) do |cmd, wrapper|
        wrapper.wrap cmd
      end

      # sudo could probably be implemented as a CmdWrapperSpec, but it's not
      # worth the hack.
      cmd = @sudo_users.reverse.reduce(cmd) do |cmd, sudo_user|
        quote_escaped_cmd = CmdWrapperSpec.quote_escape_cmd cmd
        "sudo -u #{sudo_user} -- /bin/sh -c \"#{quote_escaped_cmd}\""
      end

      cmd = "cd #{@sudo_dir};" << cmd if @sudo_dir
      cmd
    end

    class CmdWrapperSpec
      class << self
        def quote_escape_cmd(cmd)
          cmd.gsub('"', '\"').gsub('\\"', '\"')
        end
      end

      def initialize(wrapper_cmd, should_quote)
        @wrapper_cmd = wrapper_cmd
        @should_quote = should_quote
      end

      def wrap(cmd)
        if @should_quote
          cmd = CmdWrapperSpec.quote_escape_cmd cmd
        end
        cmd = "%s %s" % [@wrapper_cmd, cmd]
        cmd
      end
    end
  end

  ##
  # A facade for the shell API exposed to Loom files. This is the +loom+ object
  # passed to patterns.
  class ShellApi

    def initialize(shell)
      @shell = shell
      @mod_loader = shell.mod_loader
    end

    def local
      @shell.local.shell_api
    end

    def method_missing(name, *args, &block)
      Loom.log.debug3(self) { "shell api => #{name} #{args} #{block}" }
      @mod_loader.send name, @shell, *args, &block
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
      unless command_result.is_test
        @success &&= command_result.success?
      end
    end
  end

  class CommandResult
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
      CommandResult.new \
        cmd.command, cmd.full_stdout, cmd.full_stderr, cmd.exit_status, is_test
    end
  end

  class LocalShell < Shell
    def initialize(mod_loader, session, dry_run)
      super mod_loader, SSHKit::Backend::Local.new, dry_run
      @session = session
    end

    def local
      raise 'already in a local shell'
    end
  end
end
