describe LoomExt::CoreMods::Systemd do
  include LoomSpec::LoomInternalsHelper

  let(:fake_loom) { create_fake_shell_api }
  let(:a_fact_set) { create_fact_set }
  let(:pattern_list_units) { @reference_set['list_units'] }

  before do
    # intercept logs
    @logger_io = capture_logs_to_io
    @reference_set = create_reference_set loom_file
  end

  context "actions" do

    let(:loom_file) do
<<RB
require "loomext/all"
desc "lists systemd-units"
pattern :list_units do |l,_|
  l.systemd.is_loaded?(:my_service)
end
RB
    end

    it "should execute this" do
      pattern_list_units.call fake_loom, a_fact_set
      expect(fake_loom.cmd_execution_args.join(' '.strip)).to eql 'my_service'
    end
  end
end
