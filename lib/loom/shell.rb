require "forwardable"
require "sshkit"

module Loom
  class Shell

    VerifyError = Class.new Loom::LoomError

    def initialize(sshkit_backend, dry_run=false)
      @dry_run = dry_run
      @mod_loader = Loom::Mods::ModLoader.new self
      @session = ShellSession.new
      @shell_api = ShellApi.new self

      @sshkit_backend = sshkit_backend

      @sudo_users = []
      @sudo_dir = nil
    end

    attr_reader :session, :mod_loader, :shell_api

    def local
      @local ||= LocalShell.new @session, @dry_run
    end

    def test(*check)
      @sshkit_backend.test create_command(*check)
    end

    def verify(*check)
      raise VerifyError, check unless test *check
    end

    def verify_which(command)
      verify :which, command
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

    def execute(*args)
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

      @session << CommandResult.create_from_sshkit_command(sshkit_cmd)

      Loom.log.debug @session.last.stdout unless @session.last.stdout.empty?
      Loom.log.debug @session.last.stderr unless @session.last.stderr.empty?

      @session.last.success?
    end
    alias_method :exec, :execute

    def create_command(*args)
      cmd = args.flatten.map(&:to_s).join " "
      cmd = @sudo_users.reverse.reduce(cmd) do |cmd, sudo_user|
        quote_escaped_cmd = cmd.gsub('"', '\"').gsub('\\"', '\"')
        "sudo -u #{sudo_user} -- /bin/sh -c \"#{quote_escaped_cmd}\""
      end

      cmd = "cd #{@sudo_dir};" << cmd if @sudo_dir
      cmd
    end
  end

  ##
  # A facade for the shell API exposed to Loom files
  class ShellApi
    extend Forwardable
    def initialize(shell)
      @shell = shell
      @mod_loader = shell.mod_loader
    end

    def local
      @shell.local.shell_api
    end

    def method_missing(name, *args, &block)
      Loom.log.debug3(self) { "shell api => #{name} #{args} #{block}" }
      @mod_loader.send name, *args, &block
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
      @time = Time.now
    end

    attr_reader :command, :stdout, :stderr, :exit_status, :time

    def success?
      @exit_status == 0
    end

    def self.create_from_sshkit_command(cmd)
      return CommandResult.new cmd.command, cmd.full_stdout, cmd.full_stderr, cmd.exit_status
    end
  end

  class LocalShell < Shell
    def initialize(session, dry_run)
      super SSHKit::Backend::Local.new, dry_run
      @session = session
    end

    def local
      raise 'already in a local shell'
    end
  end
end
