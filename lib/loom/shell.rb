module Loom
  class Shell
    def initialize(sshkit_backend)
      @sshkit_backend = sshkit_backend
      @local_shell = nil
    end

    def local
      @local_shell ||= LocalShell.new
    end

    def verify(check)
      unless @sshkit_backend.test check
        raise "check failed: #{check}"
      end
    end

    def method_missing(method, *args, &block)
      execute method, *args
    end

    [:capture, :test, :within].each do |method|
      define_method method do |*args, &block|
        @sshkit_backend.send method, *args, &block
      end
    end    
    alias_method :execute, :capture
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
