module Loom::Pattern

  @included_in = []
  @pattern_slugs = []

  class << self
    attr_reader :included_in, :pattern_slugs

    def included(pattern_mod)
      @included_in << pattern_mod
      pattern_mod.extend PatternTracker
    end

  end

  module PatternTracker
    def method_added(m)
      method_slug =
        "#{self.name}:#{m}".gsub(/^LoomCli::Patterns/, "").gsub(/^:+/, "").downcase

      Loom::Pattern.pattern_slugs << method_slug
      Loom.log.debug { "pattern method_added => #{method_slug}" }
#      Loom::Pattern.pattern_methods[self.name] ||= []
#      Loom::Pattern.pattern_methods[self.name] << m
    end
  end
end
