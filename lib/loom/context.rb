module Loom::Context

  class PatternContext
    def self.run(shell, mods, host, &block)
      self.instance_exec shell, mods, host, &block
    end
  end

  class ActionContext
    def self.run(mod, inner_block, *args, &block)
      mod.instance_exec mod.shell, mod.mods, *args, &block
    end
  end

end
