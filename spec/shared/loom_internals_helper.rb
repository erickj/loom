require './lib/loom'
require './lib/loomext/all'

module LoomSpec
  module LoomInternalsHelper
    FAKE_FACTS = { :fact_one => 1, :fact_two => :two }

    def create_fact_set(fake_host: 'fake.host', fake_facts: FAKE_FACTS)
      Loom::Facts::FactSet.new fake_host, fake_facts
    end

    def create_fake_shell_api
      Loom::Shell::FakeApi.new
    end

    def create_reference_set(loom_file_src=nil, path: 'loom/file/path')
      loom_file_src ||= File.read(path)
      Loom::Pattern::ReferenceSet::Builder.create(loom_file_src, path)
    end

    def capture_logs_to_io
      logger_io = StringIO.new
      Loom.configure do |config|
        config.log_device = logger_io
      end
      logger_io
    end

    def create_dry_run_shell
    end

    def create_config(**config_map)
      Loom::Config.new config_map
    end

    def create_mod_loader(config: nil)
      config ||= create_config
      Loom::Mod::ModLoader.new config
    end
  end
end
