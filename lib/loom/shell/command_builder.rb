module Loom::Shell

  class CommandBuilder

    def initialize
      @dirs = []
      @sudoers = []
    end

    attr_reader :dirs, :sudoers

    def pushd(dir)
      unless is_absolute_path? dir
        Loom.log.warn "relative paths are not recommended => #{dir}"
      end
      @dirs.push directory
    end

    def popd
      raise "no more dirs" if @dirs.empty?
      @dirs.pop
    end

    def push_sudoer(user)
      @sudoers.push user
    end

    def pop_sudoer
      raise "no more sudoers" if @sudoers.empty?
      @sudoers.pop
    end

    # @return [String]
    def build(*cmd_parts)
      build_internal(*cmd_parts)
    end

    protected
    def build_internal(*cmd_parts)
      raise 'not implemented'
    end

    def is_absolute_path?(path)
      path.match /^\//
    end
  end

  class DefaultCommandBuilder < CommandBuilder
    def initialize(cmd_wrappers=[])
      @cmd_wrappres = cmd_wrappers
    end

    def build_internal(*cmd_parts)
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

      dirs.empty? ? cmd : "cd #{dirs.last}; " << cmd.to_s
    end
  end
end
