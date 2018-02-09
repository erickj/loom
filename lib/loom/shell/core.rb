require "forwardable"
require "shellwords"
require "sshkit"

module Loom::Shell

  class Core

    def initialize(mod_loader, sshkit_backend, dry_run=false)
      @dry_run = dry_run
      @mod_loader = mod_loader
      @sshkit_backend = sshkit_backend

      @session = Session.new
      @shell_api = Api.new self

      @cmd_wrappers = []
      @sudo_users = []

      # TODO: @sudo_dirs is a smelly workaround for not having a better
      # understanding of sudo security policies and inheriting environments.
      @sudo_dirs = []
    end

    attr_reader :session, :shell_api, :mod_loader, :dry_run

    def local
      @local ||= LocalShell.new @mod_loader, @session, @dry_run
    end

    def test(*cmd, check: :exit_status, **cmd_opts)
      # TODO: is_test smells like a hack. I can't rely on Command#is_success?
      # here (returned from execute) because I'm overriding it with :is_test =>
      # true. Fix Command#is_success? to not be a lie.. that is a lazy hack for
      # result reporting (I think the fix & feature) is to define Command
      # objects and declare style of reporting & error code handling it
      # has. Commands can be defined to ignore errors and just return their
      # results.
      execute *cmd, :is_test => true, **cmd_opts

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

    def wrap(*wrapper, first: false, should_quote: true, &block)
      raise "missing block for +wrap+" unless block_given?

      cmd_wrapper = CmdWrapper.new(*wrapper, should_quote: should_quote)

      if first
        @cmd_wrappers.unshift(cmd_wrapper)
      else
        @cmd_wrappers.push(cmd_wrapper)
      end

      begin
        yield
      ensure
        first ? @cmd_wrappers.shift : @cmd_wrappers.pop
      end
    end

    def sudo(user=nil, *sudo_cmd, &block)
      user ||= :root
      Loom.log.debug1(self) { "sudo => #{user} #{sudo_cmd} #{block}" }

      is_new_sudoer = @sudo_users.last.to_sym != user.to_sym rescue true

      @sudo_dirs.push(capture :pwd)
      @sudo_users.push << user if is_new_sudoer

      sudo_wrapper = [:sudo, "-u", user, "--", "/bin/sh", "-c"]
      sudo_cmd.compact!
      begin
        wrap *sudo_wrapper, :should_quote => true do
          execute *sudo_cmd unless sudo_cmd.empty?
          yield if block_given?
        end
      ensure
        @sudo_users.pop if is_new_sudoer
        @sudo_dirs.pop
      end
    end

    def cd(path, &block)
      Loom.log.debug1(self) { "cd => #{path} #{block}" }

      # TODO: this might creates problems with relative paths, e.g.
      # loom.cd foo => cd ./foo
      # loom.sudo user => cd ./foo; sudo user
      @sudo_dirs.push path
      begin
        @sshkit_backend.within path, &block
      ensure
        @sudo_dirs.pop
      end
    end

    def capture(*cmd_parts)
      if @dry_run
        # TODO: I'm not sure what to do about this.
        Loom.log.warn "`capture` during dry run won't do what you want"
      end
      execute *cmd_parts
      @session.last.stdout.strip
    end

    def pipe(*cmds)
      cmd = CmdWrapper.pipe *cmds.map { |*cmd| CmdWrapper.new *cmd }
      execute cmd
    end

    def execute(*cmd_parts, is_test: false, **cmd_opts)
      cmd_parts.compact!
      raise "empty command passed to execute" if cmd_parts.empty?

      result = if @dry_run
                 wrap :printf, :first => true do
                   cmd_result = execute_internal *cmd_parts, **cmd_opts
                   Loom.log.info do
                     "\t%s" % prompt_fmt(cmd_result.full_stdout.strip)
                   end
                   cmd_result
                 end
               else
                 execute_internal *cmd_parts, **cmd_opts
               end
      @session << CmdResult.create_from_sshkit_command(result, is_test, self)

      Loom.log.debug @session.last.stdout unless @session.last.stdout.empty?
      Loom.log.debug @session.last.stderr unless @session.last.stderr.empty?
      @session.last
    end
    alias_method :exec, :execute

    protected
    def prompt_label
      # TODO: get the real hostname.
      "remote"
    end

    private
    def prompt_fmt(*cmd_parts)
      output = Shellwords.join(cmd_parts).gsub /\\/, ''
      "[%s]:$ %s" % [prompt_label, output]
    end

    def execute_internal(*cmd_parts, piped_cmds: [])
      primary_cmd = create_command *cmd_parts
      piped_cmds = piped_cmds.map { |cmd_parts| CmdWrapper.new *cmd_parts }

      cmd = CmdPipeline.new([primary_cmd].concat(piped_cmds)).to_s
      # Tests if the command looks like "echo\ hi", the trailing slash after
      # echo indicates that just 1 big string was passed in and we can't really
      # isolate the execuatable part of the command. This might be fine, but
      # it's better to be strict now and relax this later if it's OK.
      if cmd.match /^[\w\-\[]+\\/i
        raise "use array parts for command escaping => #{cmd}"
      end

      Loom.log.debug1(self) { "executing => #{cmd}" }

      # This is a big hack to get access to the SSHKit command
      # object and avoid the automatic errors thrown on non-zero
      # error codes
      @sshkit_backend.send(
        :create_command_and_execute,
        cmd,
        :raise_on_non_zero_exit => false)
    end

    # Here be dragons.
    # @return [String|Loom::Shell::CmdWrapper]
    def create_command(*cmd_parts)
      cmd_wrapper = if cmd_parts.is_a? CmdWrapper
                      cmd_parts
                    else
                      Loom.log.debug3(self) { "new cmd from parts => #{cmd_parts}" }
                      CmdWrapper.new *cmd_parts
                    end

      # Useful for sudo, dry runs, timing a set of commands, or
      # timeout... anytime you want to prefix a group of commands.  Reverses the
      # array to wrap from inner most call to `#{wrap}` to outer most.
      cmd = @cmd_wrappers.reverse.reduce(cmd_wrapper) do |cmd_or_wrapper, wrapper|
        Loom.log.debug3(self) { "wrapping cmds => #{wrapper} => #{cmd_or_wrapper}"}
        wrapper.wrap cmd_or_wrapper
      end

      unless @sudo_dirs.empty? || @dry_run
        cmd = "cd #{@sudo_dirs.last}; " << cmd.to_s
      end
      cmd
    end

    # A shell object restricted to localhost.
    class LocalShell < Core
      def initialize(mod_loader, session, dry_run)
        super mod_loader, SSHKit::Backend::Local.new, dry_run
        @session = session
      end

      def local
        raise 'already in a local shell'
      end

      def prompt_label
        "local"
      end
    end
  end
end
