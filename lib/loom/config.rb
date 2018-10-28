require 'ostruct'
require 'yaml'

module Loom

  ConfigError = Class.new Loom::LoomError

  class Config

    # TODO: Add a more module config_var registry mechanism for Modules and
    # FactProviders to register their own values & defaults.
    CONFIG_VARS = {
      :loom_search_paths => ['/etc/loom', File.join(ENV['HOME'], '.loom'), './.loom'],
      :loom_files => ['site.loom'],
      :loom_file_patterns => ['*.loom'],

      :loomfile_autoloads => [
        'loomext/corefacts',
        'loomext/coremods',
      ],

      :inventory_all_hosts => false,
      :inventory_hosts => [],
      :inventory_groups => [],

      :log_level => :warn, # [debug, info, warn, error, fatal, or Integer]
      :log_device => :stderr, # [stderr, stdout, file descriptor, or file name]
      :log_colorize => true,

      :run_failure_strategy => :exclude_host, # [exclude_host, fail_fast, cowboy]
      :run_verbose => false,

      :sshkit_execution_strategy => :sequence, # [sequence, parallel, groups]
      :sshkit_log_level => :warn,
    }.freeze

    attr_reader *CONFIG_VARS.keys, :config_map

    def initialize(**config_map)
      config_map.each do |k,v|
        # allows attr_reader methods from CONFIG_VAR to work
        instance_variable_set :"@#{k}", v
      end

      @config_map = config_map
      @file_manager = FileManager.new self
    end

    def [](key)
      @config_map[key]
    end

    def to_yaml
      @config_map.to_yaml
    end
    alias_method :dump, :to_yaml # aliased to dump for debugging purposes

    # TODO: disallow CONFIG_VAR properties named after Config methods.... like
    # files. this is shitty, but I don't want to do a larger change.
    def files
      @file_manager
    end

    class << self
      def configure(config=nil, &block)
        # do NOT call Loom.log inside this block, the logger may not be
        # configured, triggering an infinite recursion

        map = config ? config.config_map : CONFIG_VARS.dup
        config_struct = OpenStruct.new **map
        yield config_struct if block_given?
        Config.new config_struct.to_h
      end
    end

    private
    class FileManager

      def initialize(config)
        @loom_search_paths = [config.loom_search_paths].flatten
        @loom_files = config.loom_files
        @loom_file_patterns = config.loom_file_patterns
      end

      def find(glob_patterns)
        search_loom_paths(glob_patterns)
      end

      def loom_files
        [@loom_files + search_loom_paths(@loom_file_patterns)].flatten.uniq
      end

      private
      def search_loom_paths(file_patterns)
        # Maps glob patterns into real file paths, selecting only
        # readable files, and logs the result.
        file_patterns.map do |file_pattern|
          @loom_search_paths.map do |path|
            Dir.glob File.join(path, "**", file_pattern)
          end
        end.flatten.uniq.select do |path|
          should_select = File.file?(path) && File.readable?(path)
          unless should_select
            Loom.log.debug1(self) { "skipping config path => #{path}" }
          end
          should_select
        end.tap do |config_files|
          unless config_files.empty?
            Loom.log.debug1(self) { "found config files => #{config_files}" }
          end
        end.uniq
      end
    end
  end
end
