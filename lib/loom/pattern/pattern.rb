module Loom::Pattern
  # A value object represnting the .loom file pattern declarations.
  class Pattern

    KINDS = %i[pattern weave report]
      .reduce({}) { |memo, k| memo.merge k => true }.freeze

    # effectively, a list of `attr_readers` for the Pattern kind. but also used
    # for validation
    KIND_KWARGS = {
      weave: [:pattern_slugs]
    }.freeze

    attr_reader :name, :description, :kind

    def initialize(name: nil, description: nil, kind: nil, **kind_kwargs, &block)
      @name = name
      @description = description
      @kind = kind
      @block = block

      @valid_kwargs = KIND_KWARGS[kind]
      kind_kwargs.each do |k, _|
        raise "unknown kind_kwarg: #{k}" unless @valid_kwargs.has? k
      end
      @kind_properties_struct = OpenStruct.new kind_kwargs
    end

    private

    KINDS.keys.each do |k|
      is_k_name = "is_#{k}?".intern
      Loom.log.debug3(self) { "defining method Loom::Pattern::Pattern+#{is_k_name}+" }
      define_method(is_k_name) { @kind == k }

      k_name = k.intern
      Loom.log.debug3(self) { "definig method Loom::Pattern::Pattern+#{k_name}+" }
      define_method(k_name) do
        if @kind != k_name
          raise "invlid call to method +#{k_name}+ on Pattern kind[#{@kind}]"
        end
        @kind_properties_struct.dup
      end
    end
  end
end
