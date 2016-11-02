module Loom::CoreMods::Files
  module Actions

    def ls(*paths)
      for_paths *paths, :action => :ls
    end

    def stat(*paths)
      for_paths *paths, :action => :stat
    end

    def cat(*paths)
      for_paths *paths, :action => :cat
    end

    def chown(*paths, user: nil, group: nil, **opts)
      group_arg = group && ":" + group

      for_paths *paths do |p|
        _.chown [user, group_arg].compact.join, p
      end
    end

    def touch(*paths)
      for_paths *paths, :action => :touch
    end

    def cd(*paths, &block)
      raise "block required for cd" unless block_given?

      for_paths *paths do |p|
        _.within p do
          yield
        end
      end
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
    alias_method :overwrite, :write!

    module Rsync
      def up(*args)
        puts "sync up #{args}"
      end

      def down(*args)
        puts "sync down #{args}"
      end
    end
  end
end
