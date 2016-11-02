module Loom
  class Shell

    def initialize(sshkit_backend)
      @sshkit_backend = sshkit_backend
    end

    def env
      execute(:env)
    end

    def verify(check)
      unless test check
        raise "check failed: #{check}"
      end
    end

    [:execute, :within, :test].each do |method|
      define_method method do |*args, &block|
        @sshkit_backend.send method, *args, &block
      end
    end

    def method_missing(method, *args, &block)
      execute(method, *args)
    end

  end
end
