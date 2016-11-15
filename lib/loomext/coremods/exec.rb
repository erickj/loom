module LoomExt::CoreMods

  FailError = Class.new Loom::ExecutionError

  ##
  # Executes shell commands from patterns. e.g.
  #
  # loom << :echo, "hello there"
  # loom.x.cd
  #
  class Exec < Loom::Mods::Module
    register_mod :exec, :alias => :<< do |mod, *args|
      Loom.log.debug2(self) { "mod exec => #{mod}:#{args}" }
      mod.shell.execute *args
    end
  end

  class ChangeDirectory < Loom::Mods::Module
    register_mod :change_directory, :alias => :cd do |mod, path, &block|
      Loom.log.debug2(self) { "mod cd => #{path} #{block}" }
      mod.shell.cd path, &block
    end
  end

  class Timeout < Loom::Mods::Module
    register_mod :timeout do |mod, timeout: 60, &block|
      Loom.log.debug2(self) { "mod timeout => timeout #{timeout}" }
      mod.shell.wrap("timeout #{timeout}", :should_quote => false, &block)
    end
  end

  class Time < Loom::Mods::Module
    register_mod :time do |mod, &block|
      Loom.log.debug2(self) { "mod time" }
      mod.shell.wrap("time", :should_quote => false, &block)
    end
  end

  class Sudo < Loom::Mods::Module
    register_mod :sudo do |mod, *args, &block|
      Loom.log.debug2(self) { "mod sudo => #{args} #{block}" }
      mod.shell.sudo *args, &block
    end
  end

  class Test < Loom::Mods::Module
    register_mod :test do |mod, *args, &block|
      Loom.log.debug2(self) { "mod test => #{args} #{block}" }
      mod.shell.test *args, &block
    end
  end

  class Fail < Loom::Mods::Module
    register_mod :fail do |mod, message|
      raise FailError, message
    end
  end
end
