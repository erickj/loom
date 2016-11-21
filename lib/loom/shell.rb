module Loom
  module Shell

    VerifyError = Class.new Loom::LoomError

    def self.create(*args)
      Loom::Shell::Core.new *args
    end
  end
end

require_relative "shell/all"
