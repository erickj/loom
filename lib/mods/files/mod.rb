require "loom/module"
require_relative "actions"

module Loom::Mods::Files
  class Files < Loom::Module::Mod

    def initialize(paths=nil)
      @paths = [paths].flatten.compact
    end

    include Actions::Core

    ns :rsync do
      include Actions::Rsync
    end

    ns :dir do
      include Actions::Dir
    end

    private
    ##
    # Executes #{action} for each path in #{paths} or #{@paths}. If
    # action is not given, a block is expected to which each path will
    # be passed.
    def for_paths(*paths, action: nil, flags: nil, &block)
      raise 'use either action or block in for_paths' if action && block_given?
      raise 'use either action or block in for_paths' unless action || block_given?

      get_paths(*paths).each do |p|
        if block
          yield p
        else
          cmd = [flags, p].join ' '
          shell.send action, cmd
        end
      end
    end

    ##
    # Returns either a list of paths used to initialize this file mod,
    # or the override paths. Paths are validated to be either absolute
    # or explicitly relative with a leading '.'
    def get_paths(*override_paths)
      paths = override_paths.empty? ? @paths : override_paths
      paths.each do |p|
        raise "prefix relative paths with '.': #{path}" unless p.match /^[.\/]/
      end
    end

  end
end
