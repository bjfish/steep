module Steep
  module TypeName
    class Base
      attr_reader :name

      def initialize(name:)
        @name = name
      end

      def ==(other)
        other.is_a?(self.class) && other.name == name
      end

      def hash
        name.hash
      end

      def eql?(other)
        self == other
      end
    end

    class Interface < Base; end
    class Module < Base; end
    class Instance < Base; end
  end
end
