module Loom::Shell
  class Session
    def initialize
      @command_results = []
      @success = true
    end

    attr_reader :command_results

    def success?
      @success
    end

    def last
      @command_results.last
    end

    def <<(command_result)
      @command_results << command_result
      unless command_result.is_test
        @success &&= command_result.success?
      end
    end
  end
end
