require 'logger'

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

    def config_changed
      SSHKit.config.output_verbosity = config.sshkit_log_level
    end

    def config_logger
      @logger = Logger.new config.log_device
      @logger.level = Logger.const_get config.log_level.upcase
      @logger.datetime_format = config.log_datetime_format
    end

    def logger
      @logger ||= config_logger
    end
  end
end

require 'loom/all'
