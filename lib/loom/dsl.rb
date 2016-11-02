module Loom
  module DSL

    def on(*args, &block)

      SSHKitShadow.on(*args) do |host|
        sshkit_backend = self

        shell = Loom::Shell.new sshkit_backend
        mods = Loom::Module::ModuleLoader.new(shell)

        Loom::Context.run(shell, mods, host, &block)
      end
    end

    def local(*args, &block)
      SSHKitShadow.run_locally(*args, &block)
    end

    def mod
      
    end

  end

  class SSHKitShadow
    extend SSHKit::DSL
  end 
end
