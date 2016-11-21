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

    def method_missing(name, *args, &block)
      Loom.log.debug3(self) { "shell api => #{name} #{args} #{block}" }
      @mod_loader.send name, @shell, *args, &block
    end
  end
end
