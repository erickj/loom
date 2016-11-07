require "loom/mods"

module Loom::CoreMods
  class Files < Loom::Mods::Module

    register_mod :files, :alias => :f

    def initialize(shell, paths=nil)
      super(shell)
      @paths = [paths].flatten.compact
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
          shell.execute action, cmd
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
        raise "prefix relative paths with '.': #{p}" unless p.match /^[.]?\//
      end
    end

    module Actions

      def chown(*paths, user: nil, group: nil, **opts)
        group_arg = group && ":" + group

        for_paths *paths do |p|
          _.chown [user, group_arg].compact.join, p
        end
      end

      def touch(*paths)
        for_paths *paths, :action => :touch
      end

      def mkdir(*paths, flags: nil, **opts)
        for_paths *paths, :action => :mkdir, :flags => flags
      end

      def append(*paths, text:)
        for_paths *paths do |p|
          _.verify "[ -f #{p} ]"
          _.echo "\"#{text}\" >> #{p}"
        end
      end

      def write(*paths, text:)
        for_paths *paths do |p|
          _.verify "[ ! -f \"#{p}\" ]"
          write! p, :text => text
        end
      end

      def write!(*paths, text:)
        for_paths *paths do |p|
          _.echo "\"#{text}\" > #{p}"
        end
      end

    end
  end

  Files.import_actions Files::Actions
end
