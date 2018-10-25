require "loom/facts"
require "loom/pattern"
require "loom/shell"

describe Loom::Pattern::DSL do

  # Fake API for tests. This object should raise an error on any command
  # execution.
  let(:fake_shell) { Loom::Shell::FakeApi.new }
  let(:a_fact_set) do
    Loom::Facts::FactSet.new('fake.host', :fact_one => 1, :fact_two => :two)
  end

  before do
    # intercept logs
    @logger_io = StringIO.new
    Loom.configure do |config|
      config.log_device = @logger_io
    end

    @reference_set = Loom::Pattern::ReferenceSet::Builder
      .create(loom_file, ':loom_file')
  end

  let(:pattern_under_test) { @reference_set['pattern_under_test'] }
  let(:inner_pattern) { @reference_set['inner:an_inner_pattern'] }

  context "pattern basics" do

    let(:loom_file) do
<<EOS
  desc "a description of pattern_under_test"
  pattern :pattern_under_test do |loom, facts|
    loom.do_outer_thing
  end

  module Inner
    include Loom::Pattern

    desc "an inner pattern"
    pattern :an_inner_pattern do |loom, facts|
      loom.do_inner_thing
    end
  end
EOS
    end

    it "defines a Pattern::Reference" do
      expect(pattern_under_test).to be_a Loom::Pattern::Reference
    end

    it "defines a reference with a desc" do
      expect(pattern_under_test.desc).to(
        eql "a description of pattern_under_test")
    end

    it "defines an inner reference with a desc" do
      expect(inner_pattern.desc).to eql "an inner pattern"
    end

    it "is runnable" do
      pattern_under_test.call fake_shell, a_fact_set
      expect(fake_shell.cmd_executions.first).to be :do_outer_thing
    end
  end

  context "#let" do

    let(:loom_file) do
<<EOS
  let(:let_var_1) { "let var 1"}
  let(:let_var_2) { "let var 2"}

  desc "a description of pattern_under_test"
  pattern :pattern_under_test do |loom, facts|
    loom.do_outer_thing(let_var_1, let_var_2)
  end

  desc "a pattern that will raise an erorr"
  pattern :bogus_pattern do |loom, facts|
    loom.do_outer_thing(let_var_3)
  end

  module Inner
    include Loom::Pattern

    let(:let_var_2) { "override let var 2"}
    let(:let_var_3) { "let var 3"}

    desc "an inner pattern"
    pattern :an_inner_pattern do |loom, facts|
      loom.do_inner_thing(let_var_1, let_var_2, let_var_3)
    end
  end
EOS
    end

    it "defines :let declartions at the top level" do
      pattern_under_test.call fake_shell, a_fact_set
      expect(fake_shell.cmd_execution_args.first).to(
        eql ["let var 1", "let var 2"])
    end

    it "defines :let declartions at inner scopes, innacessible to outer" do
      expect do
        @reference_set['bogus_pattern'].call fake_shell, a_fact_set
      end.to raise_error /^undefined local variable/
    end

    it "defines :let declarations at inner scopes, overriding outer scope" do
      inner_pattern.call fake_shell, a_fact_set
      expect(fake_shell.cmd_execution_args.first).to(
        eql ["let var 1", "override let var 2", "let var 3"])
    end
  end

  context "#with_facts" do

    let(:loom_file) do
<<EOS
  with_facts :outer_fact => :outer

  desc "a description of pattern_under_test"
  pattern :pattern_under_test do |loom, facts|
    loom.do_outer_thing facts[:outer_fact]
  end

  module Inner
    include Loom::Pattern

    with_facts :inner_fact => :inner

    desc "an inner pattern"
    pattern :an_inner_pattern do |loom, facts|
      loom.do_inner_thing(facts[:outer_fact], facts[:inner_fact])
    end
  end
EOS
    end

    it "defines fact sets at the top level" do
      pattern_under_test.call fake_shell, a_fact_set
      expect(fake_shell.cmd_execution_args.first).to(
        eql [:outer])
    end

    it "provides fact sets that get merged into inner modules" do
      inner_pattern.call fake_shell, a_fact_set
      expect(fake_shell.cmd_execution_args.first).to(
        eql [:outer, :inner])
    end
  end

  context "#report" do

    let(:report_fact_set) { a_fact_set.merge :the_report_facts => [1,2,3] }
    let(:loom_file) do
<<EOS
  let(:the_let_facts) { [:a, :b] }

  report :the_report_facts
  report :the_let_facts

  report :the_other_facts do
    { :some => :other, :stuff => :ok }
  end

  report :by_another_form, format: :json do
    { :other => :data }
  end
EOS
    end

    let(:new_stdio) { StringIO.new }
    before { $stdout = new_stdio }
    after { $stdout = STDOUT }

    it 'prints the called report by fact value' do
      @reference_set['the_report_facts'].call fake_shell, report_fact_set
      report_output = new_stdio.string
      expect(report_output).to eql [1,2,3].to_yaml
    end

    it 'prints the called report by let value' do
      @reference_set['the_let_facts'].call fake_shell, report_fact_set
      report_output = new_stdio.string
      expect(report_output).to eql [:a, :b].to_yaml
    end

    it 'prints the given report block' do
      @reference_set['the_other_facts'].call fake_shell, report_fact_set
      report_output = new_stdio.string
      expect(report_output).to eql({:some => :other, :stuff => :ok}.to_yaml)
    end

    it 'prints data in different formats' do
      @reference_set['by_another_form'].call fake_shell, report_fact_set
      report_output = new_stdio.string
      expect(report_output.strip).to eql('{"other":"data"}')
    end
  end

  context "hooks" do

    let(:loom_file) do
<<EOS

  let(:hook_order) { [] }

  before do hook_order.push("outer before hook") end
  after do hook_order.push("outer after hook") end

  desc "a description of pattern_under_test"
  pattern :pattern_under_test do |loom, facts|
    hook_order.push "execute the pattern"
    loom.do_outer_thing(hook_order)
  end

  module Inner
    include Loom::Pattern

    before do hook_order.push("inner before hook") end
    after do hook_order.push("inner after hook") end

    desc "an inner pattern"
    pattern :an_inner_pattern do |loom, facts|
      hook_order.push "execute inner pattern"
      loom.do_inner_thing(hook_order)
    end
  end
EOS
    end

    it "executes outer before hooks first and after hooks last" do
      pattern_under_test.call fake_shell, a_fact_set
      expect(fake_shell.cmd_execution_args.first).to eql [[
        "outer before hook",
        "execute the pattern",
        "outer after hook"
      ]]
    end

    it "executes nested hooks in wrapped order" do
      inner_pattern.call fake_shell, a_fact_set
      expect(fake_shell.cmd_execution_args.first).to eql [[
        "outer before hook",
        "inner before hook",
        "execute inner pattern",
        "inner after hook",
        "outer after hook"
      ]]
    end

  end

end
