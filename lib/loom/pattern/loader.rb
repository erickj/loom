module Loom::Pattern

  SiteFileNotFound = Class.new Loom::LoomError

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
      refs.flat_map { |r| r.expand_slugs }.map { |s| @reference_set[s] }
    end
  end
end
