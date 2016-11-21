module Loom::Pattern

  DuplicatePatternRef = Class.new Loom::LoomError
  UnknownPatternMethod = Class.new Loom::LoomError
  InvalidPatternNamespace = Class.new Loom::LoomError

  ##
  # A collection of Pattern::Reference objects
  class ReferenceSet

    class << self
      def load_from_file(path)
        Loom.log.debug1(self) { "loading patterns from file => #{path}" }
        Builder.create File.read(path), path
      end
    end

    def initialize
      @slug_to_ref_map = {}
    end

    def slugs
      @slug_to_ref_map.keys
    end

    def pattern_refs
      @slug_to_ref_map.values
    end

    def get_pattern_ref(slug)
      ref = @slug_to_ref_map[slug]
      raise UnknownPatternMethod, slug unless ref
      ref
    end
    alias_method :[], :get_pattern_ref

    def merge!(ref_set)
      self.add_pattern_refs(ref_set.pattern_refs)
    end

    def add_pattern_refs(refs)
      map = @slug_to_ref_map
      refs.each do |ref|
        Loom.log.debug2(self) { "adding ref to set => #{ref.slug}" }
        raise DuplicatePatternRef, ref.slug if map[ref.slug]
        map[ref.slug] = ref
      end
    end

    class Builder
      using Loom::CoreExt # using demodulize for namespace creation

      class << self
        def create(ruby_code, source)
          shell_module = Module.new
          shell_module.include Loom::Pattern
          shell_module.module_eval ruby_code, source, 1
          shell_module.namespace ""

          self.new(shell_module, source).build
        end
      end

      def initialize(shell_module, source)
        @shell_module = shell_module
        @pattern_mod_specs = pattern_mod_specs
        @source = source
      end

      def build
        ref_set = ReferenceSet.new
        ref_set.add_pattern_refs pattern_refs
        ref_set
      end

      private
      def pattern_refs
        @pattern_mod_specs.map { |mod_spec| refs_for_mod_spec mod_spec }.flatten
      end

      def refs_for_mod_spec(mod_spec)
        mod = mod_spec[:module]
        context = context_for_mod_spec mod_spec
        source = @source

        mod_spec[:pattern_methods].map do |m|
          method = mod.pattern_method m
          desc = mod.pattern_description m
          slug = compute_slug mod_spec[:namespace_list], m

          Loom.log.warn "no descripiton for pattern => #{slug}" unless desc
          Reference.new slug, method, source, context, desc
        end
      end

      def context_for_mod_spec(mod_spec)
        parents = mod_spec[:parent_modules].find_all do |mod|
          is_pattern_module mod
        end
        parent_context = parents.reduce(nil) do |parent_ctx, parent_mod|
          DefinitionContext.new parent_mod, parent_ctx
        end

        mod = mod_spec[:module]
        DefinitionContext.new mod, parent_context
      end

      def compute_slug(namespace_list, pattern_method_name)
        namespace_list.dup.push(pattern_method_name).join ":"
      end

      def mod_namespace_list(pattern, parent_modules)
        mods = parent_modules.dup << pattern
        mods.reduce([]) do |memo, mod|
          mod_name = if mod.respond_to?(:namespace) && mod.namespace
                       mod.namespace
                     else
                       mod.name.demodulize rescue ''
                     end
          if memo.size > 0 && mod_name.empty?
            raise InvalidPatternNamespace, "only the root can have an empty namespace"
          end
          memo << mod_name.downcase unless mod_name.empty?
          memo
        end
      end

      def pattern_mod_specs
        pattern_mods = []
        traverse_pattern_modules @shell_module do |pattern_mod, parent_modules|
          Loom.log.debug2(self) { "found pattern module => #{pattern_mod}" }
          pattern_methods = pattern_mod.pattern_methods

          next if pattern_methods.empty?
          pattern_mods << {
            :namespace_list => mod_namespace_list(pattern_mod, parent_modules),
            :pattern_methods => pattern_methods,
            :module => pattern_mod,
            :parent_modules => parent_modules.dup
          }
        end
        pattern_mods
      end

      def is_pattern_module(mod)
        mod.included_modules.include? Loom::Pattern
      end

      def traverse_pattern_modules(mod, pattern_parents=[], visited={}, &block)
        return if visited[mod.name] # prevent cycles
        visited[mod.name] = true

        yield mod, pattern_parents.dup if is_pattern_module(mod)

        # Traverse all sub modules, even ones that aren't
        # Loom::Pattern[s], since they might contain more sub modules
        # themselves.
        sub_modules = mod.constants
                        .map { |c| mod.const_get(c) }
                        .find_all { |m| m.is_a? Module }

        pattern_parents << mod
        sub_modules.each do |sub_mod|
          traverse_pattern_modules sub_mod, pattern_parents.dup, visited, &block
        end
      end
    end
  end
end
