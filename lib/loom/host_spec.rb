require "forwardable"
require "sshkit"

module Loom

  UnparseableHostStringError = Class.new Loom::LoomError

  class HostSpec
    extend Forwardable

    attr_accessor :disabled
    attr_reader :sshkit_host

    # TODO: change this to take an sshkit_host and make parse public. Stop calling parse from the
    # ctor.
    def initialize(host_string)
      @sshkit_host = parse host_string
    end
    def_delegators :@sshkit_host, :hostname, :user, :port

    def is_remote?
      !is_localhost?
    end

    def is_localhost?
      hostname == "localhost" && port.nil? && user.nil?
    end

    private
    def parse(host_string)
      host = SSHKit::Host.new host_string
      host.ssh_options = {
        :auth_methods => ['publickey'],
        :keys => ["~/.ssh/id_esd25519_2"],
#        :verbose => :debug,
      }
      Loom.log.debug1(self) { "parsing hoststring[#{host_string}] => #{host}" }
      Loom.log.debug1(self) { "netssh options for host[#{host}] => #{host.netssh_options}" }
      host
    end
  end
end
