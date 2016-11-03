module Loom
  StandardError = Class.new(::StandardError)

  class << self
    def configure(&block)
      @config = Loom::Config.configure @config, &block
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
      SSHKit.config.default_runner = config.sshkit_execution_strategy
      @logger = nil
    end

    def config_logger
      @logger = Loom::Logger.configure config
    end

  end
end

require 'loom/all'
