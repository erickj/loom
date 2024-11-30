  require "shellwords"

module Loom::Shell

  class CmdWrapper

    class << self
      # Escapes a shell command.
      # @param cmd [CmdWrapper|String]
      # @return [String]
      def escape(cmd)
        if cmd.is_a? CmdWrapper
          cmd.escape_cmd
        else
          Shellwords.escape(cmd)
        end
      end

      # Wraps a command in another command. See `CmdWrapper.new'
      # @param cmd_parts [CmdWrapper|String|Symbol]
      # @param should_quote [Boolean]
      def wrap_cmd(*cmd_parts, should_quote: false)
        cmd_parts = cmd_parts.map do |parts|
          if parts.respond_to? :cmd_parts
            parts.cmd_parts
          else
            parts
          end
        end
        CmdWrapper.new *cmd_parts.flatten, **{
          :should_quote => should_quote,
          :is_wrapped => true
        }
      end
    end

    # @param cmd [Array<[#to_s]>] Command parts that will be shell escaped.
    # @param :should_quote [Boolean] Whether wrapped commands should be quoted.
    # @param :redirc [Array<CmdRedirect>] STDIO redirection for the command
    # in quotes.
    def initialize(*cmd, should_quote: false, is_wrapped: false, redirect: [])
      if cmd.last.is_a?(Hash)
        raise ArgumentError.new "kwargs mixed into cmd"
      end
      @cmd_parts = cmd.flatten
      @should_quote = should_quote
      @is_wrapped = is_wrapped
      @redirects = [redirect].flatten.compact
      Loom.log.debug2(self) { "CmdWrapper.new {#{cmd}} => #{self.escape_cmd}" }
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
        CmdWrapper.wrap_cmd(*wrapped_cmd, should_quote: @should_quote)
      CmdWrapper.new(self, wrapped_cmd)
    end

    private
    def escape_inner
      escaped_parts = escape_parts(@cmd_parts)

      # Don't fuck with this unless you really want to fix it.
      if @should_quote && @is_wrapped
        double_escaped = escape_parts(escaped_parts).join " "

        # Shellwords escapes spaces, but I'm wrapping this string in another set
        # of quotes here, so it's unnecessary.
        double_escaped.gsub!(/\\(\s)/, "\\1") while double_escaped.match(/\\\s/)

        "\"#{double_escaped}\""
      else
        escaped_parts.join " "
      end
    end

    # Maps each entry of #{cmd_parts} to the escaped form of itself, except if
    # the part is frozen (like a Symbol)
    # @param cmd_parts [Array<String|Symbol|CmdWrapper>]
    # @return [Array<String|Symbol>]
    def escape_parts(cmd_parts)
      cmd_parts.map do |part|
        part.cmd_parts rescue part
      end.flatten

      cmd_parts.map do |part|
        unless part.frozen?
          CmdWrapper.escape part
        else
          part
        end
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
