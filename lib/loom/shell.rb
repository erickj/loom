require "sshkit"

module Loom
  class Shell

    VerifyError = Class.new StandardError

    def initialize(sshkit_backend)
      @sshkit_backend = sshkit_backend
      @local_shell = nil
    end

    def local
      @local_shell ||= LocalShell.new
    end

    def verify(check)
      raise VerifyError, check unless @sshkit_backend.test check
    end

    def method_missing(method, *args, &block)
      execute method, *args
    end

    def capture(*args, &block)
      Loom.log.debug { "$ #{args}" }
      @sshkit_backend.capture *args, &block
    end
    alias_method :execute, :capture

    [:test, :within, :as].each do |method|
      define_method method do |*args, &block|
        @sshkit_backend.send method, *args, &block
      end
    end
  end

  class LocalShell < Shell
    def initialize
      super SSHKit::Backend::Local.new
    end

    def local
      raise 'already in a local shell'
    end
  end
end
