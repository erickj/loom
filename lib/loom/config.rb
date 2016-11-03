require 'ostruct'
require 'yaml'

module Loom

  ConfigError = Class.new StandardError

  class Config

    CONFIG_VARS = {
      :inventory_roots => ['/etc/loom', './loom'],
      :inventory_all_hosts => false,
      :inventory_hosts => [],
      :inventory_groups => [],

      :loom_files => ['./site.loom'],

      :loom_ssh_user => 'deploy', # Can be overriden per host

      :log_level => :warn, # [debug, info, warn, error, fatal, or Integer]
      :log_device => :stderr, # [stderr, stdout, file descriptor, or file name]
      :log_colorize => true,

      :failure_stratgy => :exclude_host, # [exclude_host, fail_fast, cowboy]

      :sshkit_execution_strategy => :sequence, # [:sequence, :parallel, :groups]
      :sshkit_log_level => :warn,
    }.freeze

    attr_reader *CONFIG_VARS.keys, :config_map

    def initialize(**config_map)
      config_map.each do |k,v|
        # allows attr_reader methods from CONFIG_VAR to work
        instance_variable_set :"@#{k}", v
      end

      @config_map = config_map
    end

    def [](key)
      @config_map[key]
    end

    def to_yaml
      @config_map.to_yaml
    end
    alias_method :dump, :to_yaml # aliased to dump for debugging purposes

    class << self
      def configure(config=nil, &block)
        map = config ? config.config_map : CONFIG_VARS.dup
        config_struct = OpenStruct.new **map
        yield config_struct if block_given?
        Config.new config_struct.to_h
      end
    end
  end
end
