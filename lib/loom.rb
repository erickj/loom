module Loom
  StandardError = Class.new(::StandardError)

  class << self
    def configure(&block)
      @config = Loom::Config.configure &block
      config_changed
    end

    def config
      unless @config
        @config = Loom::Config.configure
        config_changed
      end
      @config
    end

    def log
      @logger ||= config_logger
    end

    private
    def config_changed
      SSHKit.config.output_verbosity = config.sshkit_log_level
    end

    def config_logger
      @logger = Loom::Logger.configure config
    end

  end
end

require 'loom/all'
