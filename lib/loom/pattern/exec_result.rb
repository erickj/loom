module Loom
  module Pattern

    class << self

      # @param [String] hostname
      # @param [Reference] pattern_ref
      # @return [String]
      def create_exec_id(hostname, pattern_ref)
        "%s.%s.%d" % [hostname, pattern_ref.slug, Time.now.to_i]
      end
    end

    class ExecResult

      # @param [String] hostname
      # @param [String] pattern_slug
      # @param [String] pattern_exec_id
      # @param [Boolean] result
      def initialize(hostname, pattern_slug, pattern_exec_id, result)
        @hostname = hostname
        @pattern_slug = pattern_slug
        @pattern_exec_id = pattern_exec_id
        @result = result
      end

      def succeeded?
        result
      end

      def failed?
        !succeeded?
      end
    end
  end
end
