=begin

# .loom File DSL

Loom::Pattern::DSL is the mixin that defines the declarative API for all .loom
file defined modules. It is included into Loom::Pattern by default. The outer
most module that a .loom file declares has Loom::Pattern mixed in by
default. Submodules must explicitly include Loom::Pattern, and will receive DSL.

To follow the code path for .loom file loading see:

    Loom::Runner#load
      -> Loom::Pattern::Loader.load
         -> Loom::Pattern::ReferenceSet.load_from_file
            -> Loom::Pattern::ReferenceSet::Builder.create

The Loom::Pattern::ReferenceSet::Builder creates a ReferenceSet from a .loom
file. A ReferenseSet being a collection of references with uniquely named
slugs. The slug of a reference is computed from the module namespace and
instance method name. For example, given the following .loom file:

``` ~ruby
def top_level; end

module Outer

  desc 'The first pattern'
  pattern :first do |loom, facts|; end

  module Inner
    desc 'The second pattern'
    pattern :second do |loom, facts|; end
  end
end
```

It declares a reference set with slugs:

* top_level
* outer:first
* outer:inner:second

Defining the same pattern slug twice raises a DuplicatPatternRef error.

Module Inner inherits all +let+ declarations from its outer contexts, both ::
(root) and ::Outer. +before+ hooks are run from a top-down module ordering,
+after+ hooks are run bottom-up. For example, given the following .loom file:

``` ~ruby
let(:var_1) { "v1 value" }
let(:var_2) { "v2 value" }

before { puts "runs first +before+" }
after { puts "runs last +after+" }

def top_level; end

module Submod
  let(:var_1) { "submod value" }

  before { puts "runs second +before+" }
  after { puts "runs first +after+" }

  pattern :a_pattern { |loom, facts}
end
```


If running `loom submod:a_pattern`, then let declarations would declare values:

    { :var_1 => "submod value", :var_2 => "v2 value" }

Each let value is effectively available as an `attr_reader` declaration from
::Submod#a_pattern. Before and After hook ordering with pattern execution would
look like:

    => runs first +before+
      => runs second +before+
        => `submod:a_pattern`
      => runs first +after+
    => runs last +after+

For the code that executes before hooks, pattern, after hooks see
Loom::Pattern::Reference::RunContext#run.

The Loom::Pattern::Reference::RunContext acts as the the binding object for each
pattern slug. i.e. When running a pattern slug, the RunContext is the self
object. Let definitions, before and after hooks, and fact maps are unique to
each RunContext, for each RunContext they are defined in the
Loom::Pattern::DefinitionContext. Each DefinitionContext is merged from it's
parent module, see Loom::Pattern::DefinitionContext#merge_contexts for info.

The RunContext#run method is the actual execution of the pattern. A pattern,
before association to a RunContext instance is an unbound method. During
RunContext#initialize the pattern is bound to the RunContext instance and
executed during RunContext#run with the associated Loom::Shell::Api and
Loom::Facts::FactSet as parameters.

=end
module Loom::Pattern
  module DSL

    loom_accessor :namespace

    def description(description)
      @next_description = description
    end
    alias_method :desc, :description

    def with_facts(**new_facts, &block)
      @facts ||= {}
      @facts.merge! new_facts
      yield_result = yield @facts if block_given?
      @facts = yield_result if yield_result.is_a? Hash
    end

    def let(name, &block)
      @let_map ||= {}
      @let_map[name.to_sym] = block
    end

    def pattern(name, &block)
      Loom.log.debug3(self) { "defined pattern method => #{name}" }
      @pattern_methods ||= []
      @pattern_method_map ||= {}
      @pattern_descriptions ||= {}

      method_name = name.to_sym

      @pattern_methods << method_name
      @pattern_method_map[method_name] = true
      @pattern_descriptions[method_name] = @next_description
      @next_description = nil

      define_method method_name, &block
    end

    def hook(scope, &block)
      @hooks ||= []
      @hooks << Hook.new(scope, &block)
    end

    def before(&block)
      hook :before, &block
    end

    def after(&block)
      hook :after, &block
    end

    def pattern_methods
      @pattern_methods || []
    end

    def pattern_description(name)
      @pattern_descriptions[name]
    end

    def pattern_method(name)
      raise UnknownPatternMethod, name unless @pattern_method_map[name]
      instance_method name
    end

    def hooks
      @hooks || []
    end

    def facts
      @facts || {}
    end

    def let_map
      @let_map || {}
    end
  end
end
