require 'loom/module'

class Loom::Mods::Files < Loom::Module::Mod

  def initialize(paths=nil)
    @paths = [paths].flatten.compact
  end

  action :cp do |*args|
    "cp #{args.join ' '}"
  end

  action :mv do |*args|
    "mv #{args.join ' '}"
  end

  action :ls do |*args|
    if @paths.empty?
      shell.execute :ls, *args
    else
      @paths.each do |p|
        args.unshift p
        shell.execute :ls, *args
      end
    end
  end

  action :stat do |*args|
    if @paths.empty?
      shell.execute :stat, *args
    else
      @paths.each do |p|
        args.unshift p
        shell.execute :stat, *args
      end
    end    
  end

  action :cat do |path|
    shell.execute "cat #{path}"
  end

  action :append do |path, text|
    shell.verify "[ -f #{path} ]"
    shell.execute "echo \"#{text}\" >> #{path}"
  end

  action :write do |path, text|
    shell.verify "[ ! -f \"#{path}\" ]"
    write! path, text
  end

  action :write! do |path, text|
    shell.execute "echo \"#{text}\" > #{path}"
  end
  alias_method :overwrite, :write!

end
