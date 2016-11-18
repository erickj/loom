module Loom
  class Trap

    class SignalExit < Loom::LoomError
      attr_reader :signal

      def initialize(signal)
        @signal = signal
      end
    end

    # See `man 7 signal`
    module Sig
      HUP = "HUP"
      INT = "INT"
      QUIT = "QUIT"
      TERM = "TERM"
      USR1 = "USR1"
      USR2 = "USR2"
    end

    def self.install(signal, trap_handler)
      Signal.trap signal do
        trap_handler.handle(signal)
      end
    end

    class Handler

      def initialize(&handler)
        @signal_handle_counts = {}
        @handler = handler
      end

      def handle(signal)
        @signal_handle_counts[signal] ||= 0
        @signal_handle_counts[signal] += 1

        @handler.call signal, @signal_handle_counts[signal]
      end
    end
  end
end
