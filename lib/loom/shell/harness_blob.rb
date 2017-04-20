require 'base64'
require 'digest/sha1'

module Loom::Shell

  # A blob of commands fit for sending to the harness.
  class HarnessBlob

    def initialize(cmd_blob)
      @cmd_blob = cmd_blob
    end

    attr_reader :cmd_blob

    def encoded_script
      # TODO: Fix this trailing newline hack, it is here to make encoding
      # consistent with the harness.sh script, which is a bit messy with how it
      # treats trailing newlines.
      Base64.encode64(cmd_blob + "\n")
    end

    def checksum
      Digest::SHA1.hexdigest encoded_script
    end
  end
end
