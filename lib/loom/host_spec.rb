require "forwardable"
require "sshkit"

module Loom

  UnparseableHostStringError = Class.new StandardError

  class HostSpec
    extend Forwardable

    attr_reader :sshkit_host

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
      SSHKit::Host.new host_string
    end
  end
end
