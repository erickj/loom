require "loom/mods"

module Loom::CoreMods

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

  class Sudo < Loom::Mods::Module

    register_mod :sudo do |mod, *args, &block|
      Loom.log.debug2(self) { "mod sudo => #{args} #{block}" }
      mod.shell.sudo *args, &block
    end

  end

end
