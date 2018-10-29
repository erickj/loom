require "pry"

module Loom::Pattern
  class ExpandingReference

    RecursiveExpansionError = Class.new Loom::LoomError

    # TODO: Ensure ExpandingReference and Reference stay in sync. Maybe create
    # an inheritance hierarchy.
    attr_reader :slug, :reference_slugs, :source_file, :desc, :pattern

    ##
    # @param slug [String]: flattened colon separated slug name
    # @param pattern [Loom::Pattern::Pattern]: a pattern responding to +expanded_slugs+
    def initialize(slug, pattern, reference_set)
      @slug = slug
      @reference_set = reference_set
      # TODO: Hmm... I tried to abstract the "weave" keyword from the
      # "ExpandingReference" concept... but it leaked through. Think the
      # `pattern.kind` based method name over.
      @reference_slugs = pattern.weave.expanded_slugs
      @desc = pattern.description
      @pattern
    end

    def expand_slugs
      # O(MN) :(
      expanded_slugs = @reference_slugs.flat_map do |my_slug|
        matcher = Matcher.get_matcher(my_slug)
        @reference_set.slugs.select { |your_slug| matcher.match? your_slug }
      end.uniq
      Loom.log.debug3(self) { "Loom::Pattern::ExpandingReference@reference_slugs+: #{@reference_slugs.join(",")}"}
      Loom.log.debug3(self) { "Loom::Pattern::ExpandingReference+expanded_slugs+: #{expanded_slugs.join(",")}"}

      expanded_refs = expanded_slugs.map { |s| @reference_set[s] }
      expanded_refs.each do |r|
        if r.is_a? ExpandingReference
          Loom.log.error "recursive expansion for pattern[#{r.slug}] in weave[#{@slug}], i.e. only patterns are allowed in weaves"
          raise RecursiveExpansionError, @slug
        end
      end

      Loom.log.info { "expanded slug[#{@slug}] => #{expanded_slugs.join(",")}"}
      expanded_slugs
    end

    private
    # TODO: This can be made common to some utility directory if one emerges.
    class Matcher

      def self.get_matcher(slug)
        matcher_module = [
          GlobMatcher,
          EqualityMatcher
        ].first { |m| m.handles_pattern? slug }

        Class.new(Matcher).include(matcher_module).new(slug)
      end

      def initialize(loom_pattern_slug)
        @my_slug = loom_pattern_slug
      end

      private
      module GlobMatcher
        MATCH_P = /(\*)$/

        def self.handles_pattern?(my_slug)
          res = my_slug.match? MATCH_P
          Loom.log.debug2(self) { "#{p}.match? #{MATCH_P} = #{res}" }
          res
        end

        def match?(your_pattern)
          prefix = @my_slug.to_s.gsub(MATCH_P, "")
          Loom.log.debug2(self) { "GlobMatcher+match?+ #{@my_slug} #{your_pattern}, prefix: #{prefix}"}
          your_pattern.to_s.start_with? prefix
        end
      end

      module EqualityMatcher
        def self.handles_pattern?(p)
          true
        end

        def match?(your_pattern)
          @my_slug == your_pattern
        end
      end
    end
  end
end
