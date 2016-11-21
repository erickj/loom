module LoomExt::CoreMods
  class Files < Loom::Mods::Module

    register_mod :files

    def init_action(paths)
      @paths = [paths].flatten.compact
    end

    private
    ##
    # Executes #{action} for each path in #{paths} or #{@paths}. If
    # action is not given, a block is expected to which each path will
    # be passed.
    def each_path(action: nil, flags: nil, &block)
      raise 'use either action or block in each_path' if action && block_given?
      raise 'use either action or block in each_path' unless action || block_given?

      @paths.each do |p|
        next unless p

        raise "prefix relative paths with '.': #{p}" unless p.match /^[.]?\//
        if block
          yield p
        else
          shell.execute action, flags, p
        end
      end

      # Return self for chaining in pattern files
      self
    end

    module Actions

      def cat
        each_path do |p|
          shell.capture :cat, p
        end
      end

      def rm
        each_path do |p|
          shell.capture :rm, "-f", p
        end
      end

      def match?(pattern: /./)
        all = true
        each_path do |p|
          file = shell.capture :cat, p
          all &&= file.match(pattern)
        end
        all
      end

      def gsub(pattern: nil, replace: nil, &block)
        each_path do |p|
          contents = shell.capture :cat, p
          if contents
            contents.gsub!(pattern, replace, &block) unless pattern.nil?
            write :text => contents
          end
        end
      end

      def chown(user: nil, group: nil)
        group_arg = group && ":" + group.to_s

        each_path do |p|
          shell.execute :chown, [user, group_arg].compact.map(&:to_s).join, p
        end
      end

      def touch
        each_path :action => :touch
      end

      def mkdir(flags: nil, **opts)
        each_path :action => :mkdir, :flags => flags
      end

      def append(text: "")
        text.gsub! "\n", "\\n"

        each_path do |p|
          shell.verify "[ -f #{p} ]"
          shell.exec :"/bin/echo", "-e", "'#{text}'", ">>", p
        end
      end

      def write(text: "")
        text.gsub! "\n", "\\n"

        each_path do |p|
          shell.exec :"/bin/echo", "-e", "'#{text}'", "|", :tee, p
        end
      end

    end
  end

  Files.import_actions Files::Actions
end
