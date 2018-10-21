require 'socket'

##
# Links to relevant SSHKit code:
# https://github.com/capistrano/sshkit/blob/master/lib/sshkit/backends/abstract.rb
# https://github.com/capistrano/sshkit/blob/master/lib/sshkit/backends/netssh.rb
# https://github.com/capistrano/sshkit/blob/master/lib/sshkit/backends/local.rb
module Loom

  # TODO: Rename this to something like SSHKitWrapper, DSL is a
  # terribly misinformative name.
  module DSL

    UnexpectedHostError = Class.new Loom::LoomError
    SSHConnectionError = Class.new Loom::LoomError

    ##
    # Runs the given patter_block on each host in
    # +host_specs+. +host_specs+ should be an array of String
    # hostname/connection strings or +SSHKitHost+ instances.
    #
    # +&block+ should accept an SSHKit::Backend and SSHKit::Host
    def on_host(host_specs, &run_block)
      host_specs.each do |spec|
        raise UnexpectedHostError, "not a HostSpec => #{spec}" unless spec.is_a? HostSpec
      end

      host_spec_map = host_specs.reduce({}) do |map, spec|
        map[spec.hostname] = spec
        map
      end

      execution_block = lambda do |sshkit_host|
        host_spec = host_spec_map[sshkit_host.hostname]
        Loom.log.debug1(self) { "connecting to host => #{host_spec.hostname}" }
        sshkit_backend = self

        begin
          # TODO: document the reciever of this yield
          yield sshkit_backend, host_spec
        rescue SocketError => e
          Loom.log.error "error connecting to host => #{host_spec.hostname}"
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

    # TODO: Why did I make this "shadow" class?
    class SSHKitDSLShadow
      extend SSHKit::DSL
    end
  end
end
