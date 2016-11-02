class Foo

  module Bar
    def a
      puts a
      :a
    end

    def b
      puts b
      :b
    end
  end

  class << self
    def add_method
      define_method :some_method do
        puts :foo
      end
    end
  end

  def add_instance_method(name)
    define_singleton_method name do
      puts name
    end
  end
    
end
