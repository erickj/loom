module Loom::Pattern

  ##
  # A class to act as +self+ when running pattern blocks.
  class RunContext
    def self.run(shell, mods, host, &block)
      context = self.new
      context.instance_exec shell, mods, host, &block
    end
  end

end
