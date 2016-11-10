require "yaml"

module Loom::Facts

  class FactFileProvider < Provider

    InvalidFactFileConversion = Class.new Loom::LoomError

    YAML_FILE_GLOBS = [
      "facts.yml",
      "facts/**/*.yml",
      "facts/**/*.yaml"
    ]

    TXT_FILE_GLOBS = [
      "facts.txt",
      "facts/**/*.txt"
    ]

    ALL_FILE_GLOBS = [
      "facts/**/*"
    ]

    class << self

      def create_providers(loom_config)
        providers = []

        yaml_paths = loom_config.files.find YAML_FILE_GLOBS
        providers << YAMLFactFileProvider.new(yaml_paths)

        txt_paths = loom_config.files.find TXT_FILE_GLOBS
        providers << TxtFileProvider.new(txt_paths)
      end

    end

    def initialize(paths)
      @fact_map = convert_file_paths paths
    end

    def fact_map_for_host(host_spec, &block)
      @fact_map.dup
    end

    protected
    def convert_path_to_map
      raise 'not implemented'
    end

    private
    def convert_file_paths(paths)
      paths.reduce({}) do |memo, path|
        Loom.log.debug { "loading fact file provider for => #{path}" }
        tmp_map = convert_path_to_map path
        raise InvalidFactFileConversion, path unless tmp_map.is_a? Hash
        memo.merge! tmp_map
      end
    end

    def load_config(config)
      file_paths = config.files.find @file_globs
    end
  end

  class YAMLFactFileProvider < FactFileProvider

    def convert_path_to_map(path)
      YAML.load_file path
    end

  end

  class TxtFileProvider < FactFileProvider

    def convert_path_to_map(path)
      map = {}
      File.open(path, 'r') do |io|
        io.each_line do |line|
          next if line.match /^\s*#/
          k,v = line.split "="
          map[k] = v
        end
        map
      end
    end

  end
end
