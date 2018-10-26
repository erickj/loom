module Loom::Pattern
  # A value object represnting the .loom file pattern declarations. The
  # difference between a Loom::Pattern::Pattern and Loom::Pattern::Reference is
  # a pattern has no association to the context it should run in. It is simply a
  # value object with pointers to its assigned values from the .loom
  # file. However, a Reference includes it's DefinitionContext, including nested
  # before/after/with_facts/let hooks.
  class Pattern

    KINDS = %i[pattern weave report]
      .reduce({}) { |memo, k| memo.merge k => true }.freeze

    # effectively, a list of `attr_readers` for the Pattern kind. but also used
    # for validation
    KIND_KWARGS = {
      weave: [:expanded_slugs]
    }.freeze

    attr_reader :name, :description, :kind, :pattern_block

    def initialize(name: nil, description: nil, kind: nil, **kind_kwargs, &block)
      @name = name
      @description = description
      @kind = kind
      @pattern_block = block

      @valid_kwargs = KIND_KWARGS[kind]
      kind_kwargs.each do |k, _|
        raise "unknown kind_kwarg: #{k}" unless @valid_kwargs.include? k
      end
      @kind_properties_struct = OpenStruct.new kind_kwargs
    end

    # Adds methods:
    # :is_weave?, is_pattern?, :is_reported?
    # :weave, :patttern, :reported => returns the OpenStruct of KIND_KWARGS.
    KINDS.keys.each do |k|
      is_k_name = "is_#{k}?".intern
      Loom.log.debug3(self) { "defining method Loom::Pattern::Pattern+#{is_k_name}+" }
      define_method(is_k_name) { @kind == k }

      k_name = k.intern
      Loom.log.debug1(self) { "defining method Loom::Pattern::Pattern+#{k_name}+" }
      define_method(k_name) do
        if @kind != k_name
          raise "invalid kwarg +#{k_name}+ for Pattern[#{@kind}]"
        end
        @kind_properties_struct.dup
      end
    end
  end
end
