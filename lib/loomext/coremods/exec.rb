# TODO: rename this file -> oneliners.rb
module LoomExt::CoreMods

  FailError = Class.new Loom::ExecutionError

  ##
  # Executes shell commands from patterns. e.g.
  #
  # loom << :echo, "hello there"
  class Exec < Loom::Mods::Module
    # TODO: add an "example" DSL to Loom::Mods::Module to automate
    # documentation.
    register_mod :exec, :alias => [:x, :<<] do |*cmd, **opts|
      shell.execute *cmd, **opts
    end
  end

  class ChangeDirectory < Loom::Mods::Module
    register_mod :change_directory, :alias => :cd do |path, &block|
      shell.cd path, &block
    end
  end

  class Timeout < Loom::Mods::Module
    register_mod :timeout do |timeout: 60, &block|
      shell.wrap(:timeout, timeout, :should_quote => false, &block)
    end
  end

  class Time < Loom::Mods::Module
    register_mod :time do |&block|
      shell.wrap(:time, :should_quote => false, &block)
    end
  end

  class Sudo < Loom::Mods::Module
    register_mod :sudo do |user: :root, cmd: nil, &block|
      shell.sudo user, cmd, &block
    end
  end

  class SudoCheck < Loom::Mods::Module
    register_mod :is_sudo? do
      shell.is_sudo?
    end
  end

  class Test < Loom::Mods::Module
    register_mod :test do |*cmd|
      shell.test *cmd
    end
  end

  class Fail < Loom::Mods::Module
    register_mod :fail do |message=nil|
      raise FailError, message
    end
  end

  class Upload < Loom::Mods::Module
    register_mod :upload do |local_path, remote_path|
      shell.upload local_path, remote_path
    end
  end
end
