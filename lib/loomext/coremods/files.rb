module LoomExt::CoreMods
  class Files < Loom::Mods::Module

    register_mod :files

    # TODO: document loom file statements like:
    #     `loom.files("some", "different/paths").cat`
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

      def mv(new_path)
        each_path do |p|
          shell.capture :mv, p, new_path
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
            write contents
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

      def ensure_line(line, sudo: false)
        if loom.is_sudo?
          Loom.log.warn "do not use files.ensure_line in sudo  due to poor command escaping" +
            ": use files.ensure_line and pass sudo: true"
        end

        each_path do |p|
          file = shell.capture :cat, p

          matches = file.match(/^#{line}$/)
          unless matches
            if sudo
              sudo_append(line)
            else
              append(line)
            end
          else
            Loom.log.debug(self) { "ensure_line match found: #{matches[0]}"}
          end
        end
      end

      # this is a hack to accomodate append being f'd inside sudo blocks
      def sudo_append(text="")
        if text.index "\n"
          Loom.log.warn "append lines individually until cmd escaping is fixed.... "
        end

        each_path do |p|
          text.each_line do |line|
            loom.x "/bin/echo", "-e", line, :pipe_to => [[:sudo, :tee, "-a", p]]
          end
        end
      end

      def append(text="")
        if text.index "\n"
          Loom.log.warn "append lines individually until cmd escaping is fixed.... "
        end

        if loom.is_sudo?
          Loom.log.warn "do not use files.append in sudo" +
            ": use files.sudo_append due to poor command escaping"
        end

        each_path do |p|
          # TODO: this shit is broken when escaped in a sudo command. This is
          # why I began work on the harness.
          # 	$ cd /home/pi; sudo -u root -- /bin/sh -c "/bin/echo -e 192.168.1.190 rp0\''; '\'" | tee -a /etc/hosts
          #
          text.each_line do |line|
            loom.x :"/bin/echo", "-e", line, :pipe_to => [[:tee, "-a", p]]
          end

          # TODO: fix this broken shit w/ the harness, CmdRedirect and
          # CmdWrapper are dogshit. This was an escaping attempt before harness
          # script.
          #
          # redirect = Loom::Shell::CmdRedirect.append_stdout p
          # cmd = Loom::Shell::CmdWrapper.new(
          #   :"/bin/echo", "-e", text, redirect: redirect)
        end
      end

      def write(text="")
        each_path do |p|
          loom.x :"/bin/echo", "-e", text, :pipe_to => [[:tee, p]]
        end
      end

    end
  end

  Files.import_actions Files::Actions
end
