module LoomExt::CoreMods
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
      self
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

      def cat(*paths)
        for_paths *paths do |p|
          shell.capture "cat #{p}"
        end
      end

      def rm(*paths)
        for_paths *paths do |p|
          shell.capture "rm -f #{p}"
        end
      end

      def match?(*paths, pattern: /./)
        all = true
        for_paths *paths do |p|
          file = shell.capture "cat #{p}"
          all &&= file.match pattern
        end
        all
      end

      def gsub(*paths, pattern: nil, replace: nil, &block)
        for_paths *paths do |p|
          file = shell.capture "cat #{p}"
          file.gsub!(pattern, replace, &block) unless pattern.nil?
          write p, :text => file
        end
      end

      def chown(*paths, user: nil, group: nil, **opts)
        group_arg = group && ":" + group

        for_paths *paths do |p|
          shell.exec :chown, [user, group_arg].compact.join, p
        end
      end

      def touch(*paths)
        for_paths *paths, :action => :touch
      end

      def mkdir(*paths, flags: nil, **opts)
        for_paths *paths, :action => :mkdir, :flags => flags
      end

      def append(*paths, text: "")
        text.gsub! "\n", "\\n"

        for_paths *paths do |p|
          shell.verify "[ -f #{p} ]"
          shell.exec "/bin/echo -e '#{text}' >> #{p}"
        end
      end

      def write(*paths, text: "")
        text.gsub! "\n", "\\n"

        for_paths *paths do |p|
          shell.exec "/bin/echo -e '#{text}' | tee #{p}"
        end
      end

    end
  end

  Files.import_actions Files::Actions
end
