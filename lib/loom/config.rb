require 'ostruct'

module Loom
  class Config

    CONFIG_VARS = {
      :inventory_roots => ['/etc/loom', './loom'],
      :log_level => :debug, # [debug, info, warn, error, fatal, none]
      :log_device => STDERR,
      :log_datetime_format => "%s", # http://ruby-doc.org/core-2.3.1/Time.html#method-i-strftime
      :failure_stratgy => :exclude_host # [exclude_host, fail_fast, cowboy]
      :sshkit_log_level => :debug,
    }.freeze

    attr_reader *CONFIG_VARS.keys

    def initialize(**config_map)
      config_map.each do |k,v|
        instance_variable_set :"@#{k}", v
      end
    end

    class << self
      def configure(&block)
        config_struct = OpenStruct.new **CONFIG_VARS.dup
        yield config_struct if block_given?
        Config.new config_struct.to_h
      end
    end
  end
end
