require 'loom/module'

class Loom::Mods::Files < Loom::Module::Mod

  def initialize(paths=nil)
    @paths = [paths].flatten.compact
  end

  action :ls do |*args|
    if @paths.empty?
      shell.ls *args
    else
      @paths.each do |p|
        args.unshift p
        shell.ls *args
      end
    end
  end

  action :stat do |*args|
    if @paths.empty?
      shell.stat *args
    else
      @paths.each do |p|
        args.unshift p
        shell.stat *args
      end
    end    
  end

  action :append do |path, text|
    if shell.verify "[ -f #{path} ]"
      shell.echo "\"#{text}\" >> #{path}"
    end
  end

  action :write do |path, text|
    if shell.verify "[ ! -f \"#{path}\" ]"
      write! path, text
    end
  end

  action :write! do |path, text|
    shell.echo "\"#{text}\" > #{path}"
  end
  alias_method :overwrite, :write!

end
