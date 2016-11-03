module Loom::Pattern
  class PatternReference

    attr_reader :slug

    def initialize(slug, unbound_method)
      @slug = slug
      @unbound_method = unbound_method
    end

    def bind(binding_object)
      @unbound_method.bind binding_object
    end
  end
end
