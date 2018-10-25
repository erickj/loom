module Loom::Shell

  ##
  # A facade for the shell API exposed to Loom files. This is the +loom+ object
  # passed to patterns.
  class Api

    def initialize(shell)
      @shell = shell
      @mod_loader = shell.mod_loader
      @dry_run = shell.dry_run
    end

    def dry_run?
      @dry_run
    end

    def local
      @shell.local.shell_api
    end

    # This is the entry point for `loom.foo` calls from .loom files.
    def method_missing(name, *args, &block)
      Loom.log.debug3(self) { "shell api => #{name} #{args} #{block}" }
      # TODO: The relationship between shell and mod_loader seems leaky here, a
      # Shell::Api should have a shell and not care about the mod_loader,
      # currently it seems to violate Demeter. The shell should dispatch to the
      # mod_loader only as an implementation detail. Otherwise this is harder to
      # test.
      @mod_loader.send name, @shell, *args, &block
    end
  end

  class FakeApi < Api

    # Fake Override
    def initialize
      @cmd_executions = []
      @cmd_execution_args = []
    end
    attr_reader :cmd_executions, :cmd_execution_args

    def method_missing(name, *args, &block)
      @cmd_executions.push name
      @cmd_execution_args.push args
      self
    end
  end

end
