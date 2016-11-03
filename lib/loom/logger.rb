require 'logger'

module Loom
  class Logger
    COLOR_MAP = {
      :d => :green,
      :i => :blue,
      :w => :yellow,
      :e => :red,
      :f => :pink
    }

    class << self
      def configure(config)
        device = configure_device config.log_device

        logger = ::Logger.new device
        class << logger
          include LoggerDebugLevels
        end
        raise "missing logger debug methods" unless logger.respond_to? :debug1

        logger.level = case config.log_level
                       when Symbol, String
                         ::Logger.const_get config.log_level.to_s.upcase
                       when Integer
                         # Negative numbers can be used for detailed debug levels
                         config.log_level
                       end

        colorize = config.log_colorize && device.tty?
        logger.formatter = default_formatter colorize

        if config.log_colorize && !device.tty?
          logger.warn "disabled log colorization for non-tty"
        end

        logger
      end

      private
      def configure_device(device_value)
        case device_value
        when :stderr
          STDERR
        when :stdout
          STDOUT
        when Integer
          IO.new device_value, 'a'
        when String
          File.new device_value 'a'
        else
          raise ConfigError, "log_device => #{device_value}"
        end
      end

      def default_formatter(colorize)
        lambda do |severity, datetime, progname, msg|
          s_key = severity[0].downcase.to_sym
          if colorize && COLOR_MAP[s_key]
            severity = Colorizer.send COLOR_MAP[s_key], severity
            progname = progname.nil? ? progname : Colorizer.dark_gray(progname)
          end

          if progname
            "[%s] (%s): %s\n" % [severity, progname, msg]
          else
            "[%s] %s\n" % [severity, msg]
          end
        end
      end
    end

    module LoggerDebugLevels
      NUM_DEBUG_LEVELS = 6

      ##
      # Adds methods debug1, debug2, ... debug6 for more detailed
      # debug levels. Set a negative index +logger.level+ to enable
      # lower levels, e.g. logger.level = -6 for debug6 messages.
      (1..NUM_DEBUG_LEVELS).to_a.each do |debug_level|
        debug_method_name = "debug#{debug_level}"

        define_method debug_method_name do |*args, &block|
          severity = debug_level * -1
          return if severity < self.level

          debug_at_level severity, *args, &block
        end
      end

      def format_severity(severity)
        if severity < ::Logger::DEBUG
          return "D" + severity.abs.to_s
        else
          super(severity)[0]
        end
      end

      private
      def debug_at_level(severity, progname=nil, &block)
        raise 'block required for super debug loggers' unless block_given?
        raise 'progname required for super debug loggers' unless progname

        add severity, nil, progname, &block
      end
    end

    class Colorizer
      class << self
        def colorize(color_code, str)
          "\e[#{color_code}m#{str}\e[0m"
        end

        def red(str)
          colorize 31, str
        end

        def green(str)
          colorize 32, str
        end

        def yellow(str)
          colorize 33, str
        end

        def blue(str)
          colorize 34, str
        end

        def pink(str)
          colorize 35, str
        end

        def light_blue(str)
          colorize 36, str
        end

        def light_gray(str)
          colorize 37, str
        end

        def dark_gray(str)
          colorize 90, str
        end
      end
    end

  end
end
