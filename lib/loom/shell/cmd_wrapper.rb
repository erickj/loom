require "shellwords"

module Loom::Shell

  # Escapes shell commands, use with `CmdWrapper.new :echo, '"I'm some text"'`
  class CmdWrapper

    class << self
      def escape(cmd)
        if cmd.is_a? CmdWrapper
          cmd.escape_cmd
        else
          Shellwords.escape(cmd)
        end
      end

      def wrapped_cmd(*cmd_parts, should_quote: false)
        CmdWrapper.new *cmd_parts.flatten, {
          :should_quote => should_quote,
          :is_wrapped => true
        }
      end
    end

    # @param cmd [Array<[#to_s]>] Command parts that will be shell escaped.
    # @param :should_quote [Boolean] Whether wrapped commands should be wrapped
    # in quotes.
    def initialize(*cmd, should_quote: false, is_wrapped: false, redirect: [])
      @cmd_parts = cmd.flatten
      @should_quote = should_quote
      @is_wrapped = is_wrapped
      @redirects = [redirect].flatten.compact
    end

    attr_reader :cmd_parts

    # Shell escapes each part of `@cmd_parts` and joins them with spaces.
    # @return [String]
    def escape_cmd
      escaped_cmd = escape_inner

      cmd_with_redirects = [escaped_cmd].concat @redirects.map(&:to_s)
      cmd_with_redirects.join " "
    end
    alias_method :to_s, :escape_cmd

    # @param wrapped_cmd [String]
    # @return [Array<#to_s>] The `wrapped_cmd` wrapped by `#escape_cmd`
    def wrap(*wrapped_cmd)
      wrapped_cmd =
        CmdWrapper.wrapped_cmd(*wrapped_cmd, should_quote: @should_quote)
      CmdWrapper.new(self, wrapped_cmd)
    end

    private
    def escape_inner
      escaped_parts = @cmd_parts.map do |part|
        CmdWrapper.escape part
      end

      # Don't fuck with this unless you really want to fix it.
      if @should_quote && @is_wrapped
        inner_escaped = Shellwords.join(escaped_parts)

        # Shellwords escapes spaces, but I'm wrapping this string in another set
        # of quotes here, so it's unnecessary.
        inner_escaped.gsub!(/\\(\s)/, "\\1") while inner_escaped.match(/\\\s/)

        "\"#{inner_escaped}\""
      else
        escaped_parts.join " "
      end
    end
  end

  class CmdRedirect

    class << self
      def append_stdout(word)
        CmdRedirect.new(word, mode: Mode::APPEND)
      end
    end

    # See `man bash` under REDIRECTION
    module Mode
      INPUT = :input
      OUTPUT = :output
      APPEND = :append
      OUTPUT_12 = :output_1_and_2
      APPEND_12 = :append_1_and_2
    end

    def initialize(word, fd: nil, mode: Mode::OUTPUT)
      @fd = fd
      @word = word
      @mode = mode
    end

    def to_s
      case @mode
      when Mode::INPUT
        "%s<%s" % [@fd, @word]
      when Mode::OUTPUT
        "%s>%s" % [@fd, @word]
      when Mode::APPEND
        "%s>>%s" % [@fd, @word]
      when Mode::OUTPUT_12
        "&>%s" % [@word]
      when Mode::APPEND_12
        "&>>%s" % [@word]
      else
        raise "invalid shell redirection mode: #{@mode}"
      end
    end

  end

  class CmdPipeline
    def initialize(piped_cmds)
      @piped_cmds = piped_cmds
    end

    def to_s
      @piped_cmds.map do |cmd|
        if cmd.respond_to? :escape_cmd
          cmd.escape_cmd
        else
          cmd
        end
      end.join " | "
    end
  end

end
