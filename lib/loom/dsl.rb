module Loom
  module DSL

    def on(host_spec, &block)
      SSHKitShadow.on host_spec do |host|
        Loom.log.info "on host #{host_spec}: #{host.inspect}"
        sshkit_backend = self

        # Each host needs its own shell to make sure context is preserved correctly
        shell = Loom::Shell.new sshkit_backend
        mods = Loom::Mods::ModLoader.new shell

        Loom::Context::PatternContext.run shell, mods, host, &block
      end
    end

    def local(*args, &block)
      SSHKitShadow.run_locally *args, &block
    end
  end

  class SSHKitShadow
    extend SSHKit::DSL
  end 
end
