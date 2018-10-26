# TODO: DSL extensions:
# - a way to test and verify pattern execution.... I still don't trust this
#   enough. this starts with fixing error reporting.
# - Pattern+non_idempotent+ marks a pattern as explicitly not idempotent, this
#   let's additional warnings and checks to be added
# - A history module, store a log of each executed command, a hash of the .loom
#   file, and the requisite facts (the let declarations) for each executed pattern
#   on the host it executes. /var/log/loom/history? Create this log on startup.
#   -- add a new set of history commands through the CLI and a history
#      FactProvider exposing host/loom/pattern_slug execution stats.
# - Provide automatic command reversion support with a =Module= DSL that ties in
#   with local revision history.
#   -- allow Module actions/mods to define an "undo" command of itself given the
#      original inputs to the action
#   -- using the history to pull previous params (let defns) into a revert command.
#   -- usages of the raw shell, such as `loom.x` and `loom.capture` would be
#      unsupported. so would accesses to the fact_set in any before/after/pattern
#      blocks.
#   -- however patterns that only used let blocks, and used all "revertable"
#      module methods, could have automatic state reversion and integrity checking
#      managed.
#   -- best practices (encouraged through warnings) to be to heavily discourage
#      uses of loom.execute and loom.capture in .loom files and encourage all
#      accesses to fact_set be done in let expressions (enforce this maybe?)
#   -- Later... before/after hooks can ensure the entire loom execution sequence
#      was "revertable"
# - A mechanism to allow mods to register CLI flags and actions. Using an action predicate
#   mechanisms can add flags at the global or action levels. All CLI flags set config values.
#   -- Mods can also register for action namespaces similar to git. This is consistent with mod
#      namespaces on the loom object.
#   -- Best way is to migrate loom/mods/module and loom/mods/action_proxy into base classes of
#      themselves. The isolate the shell specific behavior into a subclass of each to preserve the
#      current behavior. A new "cli" module and "cli" action proxy would enable the implementation.
# - Add a phase to the pattern execution sequence to collect calls to factset and loom
#   objects. Results collected from this ""pre-execute"" can be analyzed for errors, optimization,
#   success assertions, verification, etc. The loom file then executes in 2 passes, analyze &
#   execute.
#   -- pre-fact collection - inject the facts (or loom) object as a recorder (like a mock in record mode)
#      instead of the factual fact set. no need to change any loom files.
#   -- only run fact providers which are accessed in the pattern set
#   -- only load modules accessed in the pattern set
# - Replace Pattern "mods" and "mod specs" in Loom::Pattern::ReferenceSet with usages of a builder
#   instead. Currently the internal data model in ReferenceSet is confusing, but luckily it's the
#   only client of pattern modules, that have used Loom::Pattern::DSL. Change calls to
#   DSL#pattern/report/weave (anythin else that creates a pattern) to add a new PatternBuilder to
#   the module. Use the builder to implement the TODO above ("Add a phase..."). Implement analysis
#   on the builder.

=begin

## .loom File DSL

See:
* spec/test.loom for a valid .loom file.
* spec/loom/pattern/dsl_spec.rb for other examples


I've tried to take inspriation from several ruby DSLs, including (but not
limited to) RSpec, Thor, Commander, Sinatra... so hopefully it feels
comfortable.

Loom::Pattern::DSL is the mixin that defines the declarative API for all .loom
file defined modules. It is included into Loom::Pattern by default. The outer
most module that a .loom file declares has Loom::Pattern mixed in by
default. Submodules must explicitly include Loom::Pattern, and will receive DSL.

For example, given the following .loom file:

``` ~ruby
pattern :cmd do |loom, facts| puts loom.xe :uptime end

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

#### Code Details

To follow the code path for .loom file loading see:

    Loom::Runner#load
      -> Loom::Pattern::Loader.load
         -> Loom::Pattern::ReferenceSet.load_from_file
            -> Loom::Pattern::ReferenceSet::Builder.create

The Loom::Pattern::ReferenceSet::Builder creates a ReferenceSet from a .loom
file. A ReferenseSet being a collection of references with uniquely named
slugs. The slug of a reference is computed from the module namespace and
instance method name.

### `report`

Use `report` to create a pattern that outputs a fact, other value, or result of
a block to yaml, json, or any other format.

### `let`, `before`, and `after`

Module::Inner, from above, inherits all +let+ declarations from its outer
contexts, both :: (root) and ::Outer. +before+ hooks are run from a top-down
module ordering, +after+ hooks are run bottom-up. For example, given the
following .loom file:

``` ~ruby
let(:var_1) { "v1 value" }
let(:var_2) { "v2 value" }
let(:var_3, "otherwise") { |facts| facts[:a] || facts[:b] }

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

:var_3 would be set to either fact :a or fact :b. If the let expression
evaluates to nil?, then "otherwise" will be used as a default.

Each let value is effectively available as an `attr_reader` declaration from
::Submod#a_pattern. Because the attr_reader is defined on the RunContext scope
object, let expressions are available all before/after hooks and pattern
expresions.

Before and After hook ordering with pattern execution would
look like:

    => runs first +before+
      => runs second +before+
        => `submod:a_pattern`
      => runs first +after+
    => runs last +after+

For the code that executes before hooks, pattern, after hooks see
Loom::Pattern::Reference::RunContext#run.

#### Code Details

The Loom::Pattern::Reference::RunContext acts as the the binding object for each
pattern. i.e. RunContext is the self object for all the blocks defined in a loom
file. Let definitions, before and after hooks, and fact maps are unique to each
RunContext, for each RunContext they are defined in the
Loom::Pattern::DefinitionContext. Each DefinitionContext is merged from it's
parent module, see Loom::Pattern::DefinitionContext#merge_contexts for
info. Each pattern/host combo gets a unique RunContext instance via
Loom::Runner+execute_pattern+ -> Loom::Pattern::Reference+call+.

The RunContext#run method is the actual execution of the pattern. A pattern,
before association to a RunContext instance is an unbound method. During
RunContext#initialize the pattern is bound to the RunContext instance and
executed during RunContext#run with the associated Loom::Shell::Api and
Loom::Facts::FactSet as parameters.

See Loom::Pattern::DefinitionContext for evaluation of `let` blocks and
before/after context ordering.

### `weave`

The `weave` keyword allows aliasing a sequence of patterns a single
name. Pattern execution will be flattened and run sequentially before or after
any other patterns in the `$ loom` invocation.

``` ~ruby
pattern :step_1 { ... }
pattern :step_2 { ... }

weave :do_it, [ :step_1, :step_2 ]
```

This creates pattern :do_it, which when run `$ loom do_it` will run :step_1,
:step_2. Recursive expansion is explicitly disallowed, only pattern names (not
weaves), are allowed in the 2nd param of `weave`.

#### Code Details

Weave expansion to pattern slugs is accomplished by creating a
Loom::Pattern::ExpandingReference via the Loom::Pattern::Loader+load+ path
invoked via Loom::Runner+load+. Expansion happens on read via
Loom::Pattern::Loader+patterns+, thus the list of patterns is constant
throughout all phases of pattern execution.

#### Pattern Execution Sequence

Once hosts and patterns are identified in earlier Loom::Runner phases,
Loom::Runner+run_internal+, per host, initiates an SSH session and command
execution phases of processing the .loom file. First phase is fact collection
via +Loom::Facts.fact_set, see Loom::Facts::FactSet for createing, registering,
and executing Loom::Facts::FactProviders.

The inputs to fact collection are a Loom::Shell::Core, Loom::HostSpec, and
Loom::Config. Fact collection must be FAST and idempotent (or as reasonably
possible). No network requests should be made during fact colleciton. Fact
collection is done prior to EACH pattern/host combination in order to ensure
having the newest facts from prevoius pattern executions.

After fact collection is pattern block execution, including before and after
block execution. See comments above for pattern code pointers and other details.

## Decorating the Loom Object with Custom Modules and FactProviders

TODO

See lib/loomext/coremods & lib/loomext/corefacts for examples.

## Facts and Inventory

TODO

## Config

TODO

## Logger

TODO

##

=end

require "yaml"
require "json"

module Loom::Pattern

  PatternDefinitionError = Class.new Loom::LoomError

  # TODO: clarify this DSL to only export:
  # - description
  # - pattern
  # - let
  # - after/before
  # other methods are utility methods used to process and run patterns.
  module DSL

    def pattern_mod_init
      return if @inited

      @pattern_map = {}
      @fact_map = {}
      @let_map = {}
      @weave_slugs = {}
      @hooks = []
      @next_description = nil

      @inited = true
    end

    loom_accessor :namespace

    def description(description)
      @next_description = description
    end
    alias_method :desc, :description

    def with_facts(**new_facts, &block)
      @fact_map.merge! new_facts
      yield_result = yield @fact_map if block_given?
      @fact_map = yield_result if yield_result.is_a? Hash
    end

    def let(name, default: nil, &block)
      raise "malformed let expression: missing block" unless block_given?
      @let_map[name.to_sym] = LetMapEntry.new default, &block
    end

    def pattern(name, &block)
      define_pattern_internal(name, kind: :pattern, &block)
    end

    ##
    # @param format[:yaml|:json|:raw] default is :yaml
    def report(name, format: :yaml, &block)
      define_pattern_internal(name, kind: :report) do |loom, facts|
        # TODO: I don't like all of this logic in the dsl.
        result = if block_given?
                   Loom.log.debug(self) { "report[#{name}] from block" }
                   self.instance_exec(loom, facts, &block)
                 elsif !Loom::Facts.is_empty?(facts[name])
                   Loom.log.debug(self) { "report[#{name}] from facts[#{name}]" }
                   facts[name]
                 elsif self.respond_to?(name) && !self.send(name).nil?
                   Loom.log.debug(self) { "report[#{name}] from let{#{name}}" }
                   self.send name
                 else
                   err_msg = "no facts to report for fact[#{name}:#{name.class}]"
                   raise PatternDefinitionError, err_msg
                 end
        result = result.stdout if result.is_a? Loom::Shell::CmdResult

        puts case format
             when :yaml then result.to_yaml
             when :json then result.to_json
             when :raw then result
             else
               err_msg = "invalid report format: #{format.inspect}"
               err_msg << "valid options: yaml,json,raw"
               raise PatternDefinitionError, err_msg
             end
      end
    end

    def weave(name, pattern_slugs)
      @weave_slugs[name.to_sym] = pattern_slugs.map { |s| s.to_s }

      unless @next_description
        @next_description = "Weave runs patterns: %s" % pattern_slugs.join(", ")
      end

      define_pattern_internal(name, kind: :weave) { true }
    end

    def before(&block)
      hook :before, &block
    end

    def after(&block)
      hook :after, &block
    end

    def weave_slugs
      @weave_slugs
    end

    def is_weave?(name)
      @pattern_map[name].is_weave? rescue false
    end

    def pattern_methods
      @pattern_map.values.map &:name
    end

    def pattern_description(name)
      @pattern_map[name].description
    end

    def pattern_method(name)
      raise UnknownPatternMethod, name unless @pattern_map[name.intern]
      instance_method name
    end

    def hooks
      @hooks
    end

    def facts
      @fact_map
    end

    def let_map
      @let_map
    end

    private
    # TODO: Let mods introduce new pattern handlers. A pattern is effectively a
    # named wrapper around a pattern execution block. This would be an advanced
    # usage when before and after blocks aren't scalable. It could also provided
    # additional filtering for pattern selection at weave time.
    def define_pattern_internal(name, kind: :pattern, &loom_file_block)
      unless block_given?
        raise PatternDefinitionError, "missing block for pattern #{name}"
      end
      unless Pattern::KINDS[kind]
        raise "unknown pattern kind: #{kind}"
      end

      desc = @next_description
      unless desc.is_a?(String) || desc.nil?
        raise PatternDefinitionError, "description must be a string: #{desc.class}"
      end
      @next_description = nil
      name = name.intern

      Loom.log.debug(self) { "defined .loom pattern[#{kind}]: #{name}" }
      @pattern_map[name] =
        Pattern.new name: name, description: desc, kind: kind, &loom_file_block


      # TODO defining the method on the pattern ::Module is unnecessary, I just
      # unbind it later on and rebind it to the
      # Loom::Pattern::Reference::RunContext, so all I really need to do is
      # cache the original block.
      ##
      # ```ruby
      # pattern :xyz do |loom, facts|
      #   loom.x :dostuff
      # end
      # ```
      # Patterns declared in the .loom file are defined here:
      define_method name do |loom, facts|
        Loom.log.debug(self) { "calling .loom file #{kind}: #{name}" }
        self.instance_exec(loom, facts, &loom_file_block)
      end
    end

    def hook(scope, &block)
      @hooks << Hook.new(scope, &block)
    end
  end # DSL

  class LetMapEntry
    attr_reader :default, :block
    def initialize(default, &block)
      @default = default
      @block = block
    end
  end
end
