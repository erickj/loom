require 'ostruct'
require 'yaml'

module Loom

  ConfigError = Class.new StandardError

  class Config

    CONFIG_VARS = {
      :inventory_roots => ['/etc/loom', './loom'],
      :loom_files => ['./site.loom'],

      :loom_ssh_user => 'deploy', # Can be overriden per host
      :loom_ssh_port => 22, # Can be overriden per host
      :loom_hosts => [],
      :loom_host_groups => [],

      :log_level => :warn, # [debug, info, warn, error, fatal]
      :log_device => :stderr, # [stderr, stdout, file descriptor, or file name]
      :log_colorize => true,

      :failure_stratgy => :exclude_host, # [exclude_host, fail_fast, cowboy]

      :sshkit_log_level => :warn,
    }.freeze

    attr_reader *CONFIG_VARS.keys, :config_map

    def initialize(**config_map)
      config_map.each do |k,v|
        instance_variable_set :"@#{k}", v
      end
      @config_map = config_map
    end

    def to_yaml
      @config_map.to_yaml
    end

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
