module Loom::Pattern

  SiteFileNotFound = Class.new Loom::LoomError
  RecursiveExpansionError = Class.new Loom::LoomError

  class Loader
    class << self
      def load(config)
        loader = Loader.new config.files.loom_files
        loader.load_patterns
        loader
      end
    end

    def initialize(pattern_files)
      @loom_pattern_files = pattern_files
      @reference_set = ReferenceSet.new
    end

    def slugs
      @reference_set.slugs
    end

    def patterns(slugs=nil)
      if slugs.nil?
        @reference_set.pattern_refs
      else
        refs = slugs.map { |slug| get_pattern_ref(slug) }
        expand_refs(refs)
      end
    end

    def get_pattern_ref(slug)
      @reference_set[slug]
    end
    alias_method :[], :get_pattern_ref

    def load_patterns
      @loom_pattern_files.each do |f|
        raise SiteFileNotFound, f unless File.exists? f
        load_pattern_file f
      end
    end

    private
    def load_pattern_file(f)
      @reference_set.merge! ReferenceSet.load_from_file(f)
    end

    def expand_refs(refs)
      refs.flat_map do |ref|
        if ref.is_expanding?
          expanded_refs = ref.reference_slugs.map { |s| get_pattern_ref(s) }
          expanded_refs.each do |exp_ref|
            if exp_ref.is_expanding?
              Loom.log.error "error expanding pattern[#{exp_ref.slug}] in weave[#{ref.slug}], i.e. only patterns are allowed in weaves"
              raise RecursiveExpansionError, ref.slug
            end
          end
          Loom.log.info(
            "expanded pattern #{ref.slug} to patterns: #{expanded_refs.map(&:slug).join(",")}")
          expanded_refs
        else
          ref
        end
      end
    end
  end
end
