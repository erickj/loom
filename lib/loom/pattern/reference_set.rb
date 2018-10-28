# THERE BE DRAGONS HERE
# TODO: add documentation re: how the .loom file is parsed (exec'd) and turned
# into a reference set. There's also a lot of dark magic w/ generating
# stacktraces to get the correct .loom file line (but I forget if that's done
# here or in pattern/reference.rb maybe?)

# NB: The use of the word "mod" or "module" in this file probably means a
# ::Module, not a Loom::Mods::Module
module Loom::Pattern

  DuplicatePatternRef = Class.new Loom::LoomError
  NoReferenceForSlug = Class.new Loom::LoomError
  InvalidPatternNamespace = Class.new Loom::LoomError

  ##
  # A collection of Pattern::Reference objects
  class ReferenceSet

    class << self
      def load_from_file(path)
        Loom.log.debug1(self) { "loading patterns from file => #{path}" }
        builder(File.read(path), path).build
      end

      def builder(file_src, file_path)
        Builder.create(file_src, file_path)
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
      raise NoReferenceForSlug, slug unless ref
      ref
    end
    alias_method :[], :get_pattern_ref

    def merge!(ref_set)
      add_pattern_refs(ref_set.pattern_refs)
    end

    def add_pattern_refs(refs)
      refs.each do |ref|
        Loom.log.debug2(self) { "adding ref to set => #{ref.slug}" }
        raise DuplicatePatternRef, ref.slug if @slug_to_ref_map[ref.slug]
        @slug_to_ref_map[ref.slug] = ref
      end
    end

    class Builder
      using Loom::CoreExt # using demodulize for namespace creation

      class << self
        def create(ruby_code, source_file)
          # Creates an anonymous parent module in which to evaluate the .loom
          # file src. This module acts as a global context for the .loom file.
          # TODO: How should this be hardened?
          shell_module = Module.new
          shell_module.include Loom::Pattern
          # TODO: I think this is my black magic for capturing stacktrace
          # info... I forget the details. Add documentation.
          # TODO: This is where I would need to hack into to auto-include
          # Loom::Pattern in .loom file modules
          shell_module.module_eval ruby_code, source_file, 1
          shell_module.namespace ""

          self.new shell_module, source_file
        end
      end

      def initialize(shell_module, source_file)
        @shell_module = shell_module
        @source_file = source_file
      end

      def build
        ref_set = ReferenceSet.new

        dsl_specs = create_dsl_specs
        pattern_refs = create_pattern_refs dsl_specs, ref_set

        ref_set.add_pattern_refs pattern_refs
        ref_set
      end

      private
      # TODO: I don't like passing in the ref set build target here.... but
      # ExpandingReference needs it... Can I do this w/o an instance variable
      # and w/o plumbing the param through methods?
      def create_pattern_refs(dsl_specs, builder_target_ref_set)
        dsl_specs.flat_map do |dsl_spec|
          create_refs_for_dsl_spec dsl_spec, builder_target_ref_set
        end
      end

      def create_refs_for_dsl_spec(dsl_spec, builder_target_ref_set)
        context = create_defn_context_for_dsl_spec dsl_spec

        dsl_spec[:dsl_builder].patterns.map do |pattern|
          slug = compute_slug dsl_spec[:namespace_list], pattern.name

          case pattern.kind
          when :weave
            Loom.log.debug2(self) { "adding ExpandingReference for weave: #{slug}" }
            create_expanding_reference(pattern, slug, builder_target_ref_set)
          else
            Loom.log.debug2(self) { "adding Reference for pattern: #{slug}" }
            create_pattern_reference(pattern, slug, context)
          end
        end
      end

      def create_expanding_reference(pattern, slug, ref_set)
        desc = pattern.description
        Loom.log.warn "no descripiton for weave => #{slug}" unless desc

        ExpandingReference.new slug, pattern, ref_set
      end

      def create_pattern_reference(pattern, slug, context)
        desc = pattern.description
        Loom.log.warn "no descripiton for pattern => #{slug}" unless desc

        Reference.new slug, pattern, @source_file, context
      end

      # Creates a DefinitionContext for dsl_module by flattening and mapping
      # parent ::Modules to a contextualized DefinitionContext.
      def create_defn_context_for_dsl_spec(dsl_spec)
        parents = dsl_spec[:parent_modules].find_all do |mod|
          dsl_module? mod
        end
        parent_context = parents.reduce(nil) do |parent_ctx, parent_mod|
          DefinitionContext.new parent_mod.dsl_builder, parent_ctx
        end
        DefinitionContext.new dsl_spec[:dsl_builder], parent_context
      end

      def compute_slug(namespace_list, pattern_method_name)
        namespace_list.dup.push(pattern_method_name).join ":"
      end

      def create_namespace_list(pattern, parent_modules)
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

      def create_dsl_specs
        dsl_mods = []
        traverse_dsl_modules @shell_module do |dsl_mod, parent_modules|
          Loom.log.debug2(self) { "found pattern module => #{dsl_mod}" }

          dsl_builder = dsl_mod.dsl_builder
          next if dsl_builder.patterns.empty?

          dsl_mods << {
            namespace_list: create_namespace_list(dsl_mod, parent_modules),
            dsl_builder: dsl_builder,
            dsl_module: dsl_mod,
            parent_modules: parent_modules
          }
        end
        dsl_mods
      end

      def dsl_module?(mod)
        mod.included_modules.include? Loom::Pattern
      end

      # Recursive method to walk the tree of dsl_builders representative of the
      # .loom file pattern modules
      def traverse_dsl_modules(mod, pattern_parents=[], visited={}, &block)
        return if visited[mod.name] # prevent cycles
        visited[mod.name] = true

        yield mod, pattern_parents.dup if dsl_module?(mod)

        # Traverse all sub modules, even ones that aren't
        # Loom::Pattern[s], since they might contain more sub modules
        # themselves.
        sub_modules = mod.constants
                        .map { |c| mod.const_get(c) }
                        .find_all { |m| m.is_a? Module }

        pattern_parents << mod
        sub_modules.each do |sub_mod|
          traverse_dsl_modules sub_mod, pattern_parents.dup, visited, &block
        end
      end
    end
  end
end
