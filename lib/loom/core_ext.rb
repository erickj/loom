module Loom::CoreExt
  refine String do
    def underscore
      self.gsub(/[^\w]+/, '_').downcase
    end

    def demodulize
      self.split('::').last
    end
  end
end
