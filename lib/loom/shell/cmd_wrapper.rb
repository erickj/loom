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
    def initialize(*cmd, should_quote: false, is_wrapped: false)
      @cmd_parts = cmd.flatten
      @should_quote = should_quote
      @is_wrapped = is_wrapped
    end

    attr_reader :cmd_parts

    # Shell escapes each part of `@cmd_parts` and joins them with spaces.
    # @return [String]
    def escape_cmd
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
    alias_method :to_s, :escape_cmd

    # @param wrapped_cmd [String]
    # @return [Array<#to_s>] The `wrapped_cmd` wrapped by `#escape_cmd`
    def wrap(*wrapped_cmd)
      wrapped_cmd =
        CmdWrapper.wrapped_cmd(*wrapped_cmd, should_quote: @should_quote)
      CmdWrapper.new(self, wrapped_cmd)
    end
  end
end
