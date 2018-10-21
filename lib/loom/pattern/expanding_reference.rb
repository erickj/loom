module Loom::Pattern
  class ExpandingReference

    attr_reader :slug, :reference_slugs, :source_file, :desc

    def initialize(slug, reference_slugs, source_file, description)
      @slug = slug
      @reference_slugs = reference_slugs
      @desc = description
    end

    def is_expanding?
      true
    end
  end
end
