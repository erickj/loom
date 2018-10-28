# IN Progress:
# [wip-patternbuilder]
# * Add a phase to the pattern execution sequence to collect calls to factset and loom
#   objects. Results collected from this ""pre-execute"" can be analyzed for errors, optimization,
#   success assertions, verification, etc. The loom file then executes in 2 passes, analyze &
#   execute.
#   -- pre-fact collection - inject the facts (or loom) object as a recorder
#   -- (like a mock in record mode) # instead of the factual fact set. no need
#   -- to change any loom files.
#   -- only run fact providers which are accessed in the pattern set
#   -- only load modules accessed in the pattern set
#
# * Replace Pattern "mods" and "mod specs" in 80 Loom::Pattern::ReferenceSet
#   with usages of a builder instead. Currently the internal data model in
#   ReferenceSet is confusing, but luckily it's the only client of pattern
#   modules, that have used Loom::Pattern::DSL. Change calls to
#   DSL#pattern/report/weave (anythin else that creates a pattern) to add a new
#   PatternBuilder to the module. Use the builder to implement the TODO above
#   ("Add a phase..."). Implement analysis on the builder.
# [master]
# * ... ongoing ... ways to test and +verify+ pattern execution

# TODO: DSL extensions:
# - More Mods! .... ondeck:
#   * bkblz
#   * cassandra
#   * apache (nginx?)
#   * digital ocean
#   * systemd-nspawj

# - Models Future:
#   Notice each ondeck module above (bkblz, cassanadra, apache, digital ocean,
#   system-nspawn): covers a unique infrastructure area, i.e.: bkblz:object and
#   cold storage, cassandra:hyper-scale data storage, apache/nginx:content
#   serving, digital-ocean/aws/gcp:remote virtual hosting, containers:local
#   virtual hosting
#   I could generalize each of the above infrastructure area into a high level
#   mod. Should I? Maybe not.

# - auto mod documentation in the CLI

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

=begin

## .loom File DSL

See:
* spec/.loom/*.loom for a lots of valid .loom files.
  * run these specs with `rspec spec/test_loom_spec.rb`
* spec/loom/pattern/dsl_spec.rb for other examples


I've tried to take inspriation from several ruby DSLs, including RSpec, Thor,
Commander, Sinatra... so hopefully it feels comfortable. Thank you to all of
those projects.

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

* cmd
* outer:first
* outer:inner:second

Defining the same pattern slug twice raises a `DuplicatePatternRef` error.

#### Code Details

Loom::DSL is a facade available to all .loom file ::Modules that include
Loom::Pattern. It provides Module singleton methods listed at
Loom::DSL::DSL_METHODS.

Code path for .loom file loading:

    Loom::Runner#load
      -> Loom::Pattern::Loader.load
         -> Loom::Pattern::ReferenceSet.load_from_file
            -> Loom::Pattern::ReferenceSet::Builder.create

The Loom::Pattern::ReferenceSet::Builder creates a ReferenceSet from a .loom
file. A ReferenseSet being a collection of references with uniquely named
slugs. The slug of a reference is computed from the module namespace and
instance method name.

### `weave`

The `weave` creates a specialized pattern, that allows aliasing a sequence of
pattern slugs as a single pattern name. Pattern execution will be flattened and
run sequentially before or after any other patterns in the `$ loom` invocation.

``` ~ruby
pattern :step_1 { ... }
pattern :step_2 { ... }

module OtherTasks
...
end

weave :do_it, [ :step_1, :step_2, :other_tasks:* ]
```

This creates pattern :do_it, which when run `$ loom do_it` will run :step_1,
:step_2, and all slugs that match /other_tasks.*/. Recursive expansion is
explicitly disallowed, only pattern names (not weaves), are allowed in the list
of weave pattern slugs.

#### Code Details

Weave expansion to pattern slugs is accomplished by creating a
Loom::Pattern::ExpandingReference via the Loom::Pattern::Loader+load+ path
invoked via Loom::Runner+load+. Expansion happens on read via
Loom::Pattern::Loader+patterns+, thus the list of patterns is constant
throughout all phases of pattern execution.

### `report`

Use `report` to create another specialized pattern that prints a fact, value,
or result of a block to yaml, json, or any other format to STDOUT.

### `let`, `before`, and `after`: for examples spec/.loom/parent_context.loom

`let`, does the same as in RSpec (including the context details). It creates an
alias for a value, available in all patterns.

`before` and `after` are similar to the same in RSpec. Each before/after block
is run before/after respectively to EACH pattern.

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

  DSL_METHODS = [
    :desc,
    :description,

    :pattern,
    :weave,
    :report,

    :with_facts,
    :let,
    :before,
    :after,

    :namespace
  ]

  ##
  # The Loom DSL definition. See documentation above.
  module DSL
    DSL_METHODS.each do |m|
      define_method m do |*args, &block|
        Loom.log.debug1(self) { "delegating Pattern::DSL call to DSLBuilder+#{m}+" }
        @dsl_builder.send(m, *args, &block)
      end
    end

    attr_reader :dsl_builder

    class << self
      def extended(receiving_mod)
        # NB: Using Forwardable was awkward here due to the scope of extended, and
        # the scope of where the fordwardable instance variable would live.
        dsl_builder = PatternBuilder.new
        receiving_mod.instance_variable_set :@dsl_builder, dsl_builder
      end
    end
  end

  class DSL::PatternBuilder

    def initialize
      @pattern_map = {}
      @fact_map = {}
      @let_map = {}
      @hooks = []
      @next_description = nil
    end

    # BEGIN DSL Implementation
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
        # TODO: I don't like all of this logic here. It feels like it belongs in
        # a mod.
        result = if block_given?
                   Loom.log.debug(self) { "report[#{name}] from block" }
                   instance_exec(loom, facts, &block)
                 elsif !Loom::Facts.is_empty?(facts[name])
                   Loom.log.debug(self) { "report[#{name}] from facts[#{name}]" }
                   facts[name]
                 elsif respond_to?(name) && !self.send(name).nil?
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
      unless @next_description
        @next_description = "Weave runs patterns: %s" % pattern_slugs.join(", ")
      end
      define_pattern_internal(name, kind: :weave, expanded_slugs: pattern_slugs) { true }
    end

    def before(&block)
      hook :before, &block
    end

    def after(&block)
      hook :after, &block
    end
    # END DSL Implementation

    def patterns
      @pattern_map.values
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
    def define_pattern_internal(name, kind: :pattern, **kwargs, &loom_file_block)
      unless block_given?
        raise PatternDefinitionError, "missing block for pattern[#{name}]"
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

      Loom.log.debug(self) { "defined .loom pattern[kind:#{kind}]: #{name}" }
      @pattern_map[name] = Pattern.new(
        name: name, description: desc, kind: kind, **kwargs, &loom_file_block)

      # TODO: defining the method on the pattern ::Module is unnecessary, I just
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
      define_singleton_method name do |loom, facts|
        Loom.log.debug(self) { "calling .loom file #{kind}: #{name}" }
        instance_exec(loom, facts, &loom_file_block)
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
