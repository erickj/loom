module Loom::Pattern

  SiteFileNotFound = Class.new Loom::LoomError
  UnknownPattern = Class.new Loom::LoomError
  PollutedPatternContainer = Class.new Loom::LoomError

  class Loader
    class << self
      def configure(config)
        loader = Loader.new config.files.loom_files
        loader.load_patterns
        loader
      end
    end

    def initialize(pattern_files)
      @loom_pattern_files = pattern_files
      @pattern_ref_map = {}
    end

    def get_pattern_ref(slug)
      @pattern_ref_map[slug]
    end
    alias_method :[], :get_pattern_ref

    def loaded_patterns
      @pattern_ref_map.values
    end

    def load_patterns
      @loom_pattern_files.each do |f|
        raise SiteFileNotFound, f unless File.exists? f
        load_pattern_file f
      end
    end

    private
    def load_pattern_file(f)
      Loom.log.debug1(self) { "loading pattern file: #{f}" }
      Shell.module_eval File.read f

      register_pattern_refs Shell, f
    end

    def register_pattern_refs(shell_module, source_file, visited_modules={})
      if visited_modules[shell_module.name]
        # Avoid circularities
        return
      end
      visited_modules[shell_module.name] = true

      if shell_module.included_modules.include? Loom::Pattern::Container
        Loom.log.debug1(self) { "registering pattern module => #{shell_module.name}" }

        if shell_module.included_modules.size > 1
          # TODO: A DSL to define pattern methods would be more appropriate here.
          raise PollutedPatternContainer,
                "PatternContainer <#{shell_module.name}> should include no other modules"
        end

        trimmed_module_name = PatternNameTrimer.trim_shell_from_module_name shell_module
        shell_module.instance_methods.each do |pattern_method_name|
          unbound_method = shell_module.instance_method pattern_method_name

          # Cleanup the slug name from the fully qualified
          # Loom::Pattern::Loader::Shell namespace, leaving any
          # submodules and method names.
          pattern_slug = PatternNameTrimer.create_pattern_slug \
            trimmed_module_name, pattern_method_name

          ref = PatternReference.new(
            pattern_slug, unbound_method, trimmed_module_name, source_file)
          add_pattern_ref ref
        end
      end

      # Recurse through sub-modules
      shell_module.constants
        .map { |c| shell_module.const_get c }
        .select { |c| c.is_a? Module }
        .each { |mod| register_pattern_refs mod, source_file, visited_modules }
    end

    def add_pattern_ref(pattern_ref)
      Loom.log.debug2(self) { "#add_pattern_ref => #{pattern_ref.slug}" }
      @pattern_ref_map[pattern_ref.slug] = pattern_ref
    end

    class PatternNameTrimer
      using Loom::CoreExt

      class << self
        def trim_shell_from_module_name(pattern_module)
          "#{pattern_module.name}".gsub(/^#{Shell.name}/, '').gsub(/^[\W]+/, '').strip
        end

        def create_pattern_slug(trimmed_module_name, pattern_method_name)
          [trimmed_module_name, pattern_method_name]
            .delete_if(&:empty?)
            .map(&:to_s)
            .map { |s| s.underscore } # don't use &: here, it doesn't play well with refinement
            .join ":"
        end
      end
    end

    module Shell
      # Intentionally left empty - used to load patterns into.
    end
  end
end
