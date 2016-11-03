require 'logger'

module Loom
  class Logger
    COLOR_MAP = {
      :debug => :green,
      :info => :blue,
      :warn => :yellow,
      :error => :red,
      :fatal => :pink
    }

    class << self
      def configure(config)
        device = config.log_device
        if device.is_a? String
          device = File.open device, 'a'
        end

        logger = ::Logger.new device
        logger.level = ::Logger.const_get config.log_level.upcase

        colorize = config.log_colorize && device.tty?
        logger.formatter = default_formatter colorize

        if config.log_colorize && !device.tty?
          logger.warn "disabled log colorization for non-tty"
        end

        logger
      end

      def default_formatter(colorize)
        lambda do |severity, datetime, progname, msg|
          s_code = severity[0]
          if colorize && COLOR_MAP[severity.downcase.to_sym]
            s_code = Colorizer.send COLOR_MAP[severity.downcase.to_sym], s_code
          end        
          "[%s] %s\n" % [s_code, msg]
        end
      end
    end

    class Colorizer
      class << self
        def colorize(color_code, str)
          "\e[#{color_code}m#{str}\e[0m"
        end

        def red(str)
          colorize(31, str)
        end

        def green(str)
          colorize(32, str)
        end

        def yellow(str)
          colorize(33, str)
        end

        def blue(str)
          colorize(34, str)
        end

        def pink(str)
          colorize(35, str)
        end

        def light_blue(str)
          colorize(36, str)
        end
      end
    end

  end
end
