module StringExt
  def underscore
    self.gsub(/[^\w]+/, '_').downcase
  end

  def demodulize
    self.split('::').last
  end
end

class String
  include StringExt
end

