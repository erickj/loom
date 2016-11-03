require 'socket'

module Loom
  module DSL

    UnexpectedHostError = Class.new Loom::LoomError
    SSHConnectionError = Class.new Loom::LoomError

    ##
    # Runs the given patter_block on each host in
    # +host_specs+. +host_specs+ should be an array of String
    # hostname/connection strings or +SSHKitHost+ instances.
    #
    # +&block+ should accept 3 arguments, a Loom::Shell, a
    # Loom::ModLoader, and the current +SSHKitHost+
    def on_host(host_specs, binding_context, &pattern_block)
      host_specs.each do |spec|
        raise UnexpectedHostError, "not a HostSpec => #{spec}" unless spec.is_a? HostSpec
      end

      execution_block = lambda do |host|
        Loom.log.debug1(self) { "connecting to host => #{host.hostname}" }
        sshkit_backend = self

        # Each host needs its own shell and mod loader to make sure
        # context is preserved correctly
        shell = Loom::Shell.new sshkit_backend
        mods = Loom::Mods::ModLoader.new shell

        begin
          yield shell, mods, host
        rescue SocketError => e
          Loom.log.error "error connecting to host => #{host.hostname}"
          raise SSHConnectionError, e
        end
      end

      local_specs = host_specs.select { |s| s.is_localhost? }
      unless local_specs.empty?
        Loom.log.debug1(self) do
          "local execution for host entry => #{local_specs.first}"
        end
        SSHKitDSLShadow.run_locally &execution_block
      end

      remote_specs = host_specs.select { |s| s.is_remote? }.map(&:sshkit_host)
      unless remote_specs.empty?
        Loom.log.debug1(self) { "remoted execution for #{remote_specs.size} hosts" }
        SSHKitDSLShadow.on remote_specs, &execution_block
      end
    end

    class SSHKitDSLShadow
      extend SSHKit::DSL
    end
  end
end
