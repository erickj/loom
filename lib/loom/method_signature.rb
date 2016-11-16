module Loom

  # Used to analyze the arguments of a method.
  class MethodSignature

    module ParamType
      REQ = :req
      OPT = :opt
      REST = :rest
      KEYREQ = :keyreq
      KEY = :key
      KEYREST = :keyrest
      BLOCK = :block
    end

    # @param proc_or_method [#parameters] A {Proc} or {Method}
    def initialize(proc_or_method)
      @parameter_list = proc_or_method.parameters
      @req_args = find_by_type ParamType::REQ
      @opt_args = find_by_type ParamType::OPT
      @rest_args = find_by_type ParamType::REST
      @keyreq_args = find_by_type ParamType::KEYREQ
      @key_args = find_by_type ParamType::KEY
      @keyrest_args = find_by_type ParamType::KEYREST
      @block_args = find_by_type ParamType::BLOCK
    end

    attr_reader :req_args, :opt_args, :rest_args, :keyreq_args, :key_args,
                :keyrest_args, :block_args

    def find_by_type(type)
      @parameter_list.find_all { |tuple| tuple.first == type }
    end

    # Defines has_xyz_args? methods for each {ParamType}.
    def method_missing(name, *args)
      match_data = name.to_s.match /^has_([^?]+)_args\?$/
      if match_data
        method = "%s_args" % [match_data[1]]
        !self.send(method.to_sym).empty?
      else
        super name, *args
      end
    end

    class MatchSpec

      class Builder
        def initialize
          @map = {
            :req_args => 0,
            :opt_args => 0,
            :has_rest_args => false,
            :keyreq_args => 0,
            :key_args => 0,
            :has_keyrest_args => false,
            :has_block => false
          }
        end

        def method_missing(name, value, *args)
          @map[name.to_sym] = value
          self
        end

        def build
          MatchSpec.new(@map || {})
        end
      end

      class << self
        def builder
          Builder.new
        end
      end

      # @param req_args [Fixnum] Number of required args, nil for any.
      # @param opt_args [Fixnum] Number of optional args, nil for any.
      # @param has_rest_args [Boolean] Whether a *args is defined, nil
      #     for any. If +has_rest_args+ is true then any number of req or opt
      #     args will satisfy this match.
      # @param keyreq_args [Fixnum] Number of required keyward args, nil
      #     for any.
      # @param key_args [Fixnum] Number of optional keyward args, nil
      #     for any.
      # @param has_keyrest_args [Boolean] Whether a **opts is defined,
      #     nil for any. If +has_keyrest_args+ is true, then any number of
      #     keyreq or key args will satisfy this match for name named opts.
      # @param has_block [Boolean] Whether a block is defined, nil for any.
      def initialize(
            req_args: nil,
            opt_args: nil,
            has_rest_args: nil,
            keyreq_args: nil,
            key_args: nil,
            has_keyrest_args: nil,
            has_block: nil)
        @req_args = req_args
        @opt_args = opt_args
        @has_rest_args = has_rest_args
        @keyreq_args = keyreq_args
        @key_args = key_args
        @has_keyrest_args = has_keyrest_args
        @has_block = has_block
      end

      # @return [Boolean]
      def match?(method)
        method_sig = MethodSignature.new method

        # *args definition matches any call.
        return true if @has_rest_args

        check_ordered_args(method_sig) &&
          check_keyword_args(method_sig) &&
          check_block_args(method_sig)
      end

      private
      def check_ordered_args(method_sig)
        rest = check_rest(method_sig)
        if rest && method_sig.has_rest_args?
          Loom.log.debug1(self) { "returning from failed addon look"}
          return true
        end

        return rest &&
               check_req_args(method_sig) &&
               check_opt_args(method_sig);
      end

      def check_rest(method_sig)
        @has_rest_args.nil? || method_sig.has_rest_args? == @has_rest_args
      end

      def check_req_args(method_sig)
        @req_args.nil? || @req_args == method_sig.req_args.size
      end

      def check_opt_args(method_sig)
        @opt_args.nil? || @opt_args == method_sig.opt_args.size
      end

      def check_keyword_args(method_sig)
        return true if @has_keyrest_args

        return check_keyrest(method_sig) &&
               check_keyreq_args(method_sig) &&
               check_key_args(method_sig);
      end

      def check_keyrest(method_sig)
        @has_keyrest_args.nil? || method_sig.has_keyrest_args? == @has_keyrest_args
      end

      def check_keyreq_args(method_sig)
        @keyreq_args.nil? ||
          @keyreq_args == method_sig.keyreq_args.size ||
          method_sig.has_keyrest_args?
      end

      def check_key_args(method_sig)
        @key_args.nil? ||
          @key_args == method_sig.key_args.size ||
          method_sig.has_keyrest_args?
      end

      def check_block_args(method_sig)
        return true if @has_block.nil?
        return method_sig.has_block_args? == @has_block
      end
    end
  end
end
