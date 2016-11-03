module Loom::Pattern

  SiteFileNotFound = Class.new StandardError
  UnknownPattern = Class.new StandardError

  @loaded_pattern_slugs = {}

  class << self
    attr_reader :included_in, :pattern_slugs, :loaded_pattern_slugs

    def included(pattern_mod)
      pattern_mod.extend PatternTracker
      Loom.log.debug { "Loom::Patttern included in #{pattern_mod}" }
    end

    def method_for_slug(slug)
      @loaded_pattern_slugs[slug]
    end
  end

  module PatternTracker
    def method_added(method)
      pattern_slug =
        "#{self.name}:#{method}".gsub(/^Loom::Pattern::Shell/, "").gsub(/^:+/, "").downcase

      Loom::Pattern.loaded_pattern_slugs[pattern_slug] = method
      Loom.log.debug { "pattern method_added => #{pattern_slug}" }
    end
  end

  class Shell
    # Intentionally left empty - used to load patterns into.
  end

  class Runner
    include Loom::DSL

    def initialize(pattern_slugs=[])
      @pattern_slugs = pattern_slugs
      @loom_pattern_files = Loom.config.loom_files
      load_patterns
    end

    def run
      inventory = Loom::Inventory.active_inventory
      active_hosts = inventory.hosts

      @pattern_slugs.each do |pattern|
        method = Loom::Pattern.method_for_slug pattern
        raise UnknownPattern, pattern unless method

        on active_hosts do |shell, mods, host|
          Loom.log.info "#{host.hostname} => #{pattern}"
          binding_object = Shell.new
          binding_object.send method, shell, mods, host
        end

      end
    end

    def patterns
      Loom::Pattern.loaded_pattern_slugs.keys
    end

    private
    def load_patterns
      @loom_pattern_files.each do |f|
        raise SiteFileNotFound, f unless File.exists? f
        load_site_file f
      end
    end

    def load_site_file(f)
      Loom.log.debug "loading site file #{File.realpath f} into shell"
      Shell.module_eval File.read f
    end
  end
end
