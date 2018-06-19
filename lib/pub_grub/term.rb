require 'forwardable'

module PubGrub
  class Term
    attr_reader :constraint, :positive

    def initialize(constraint, positive)
      @constraint = constraint
      @positive = positive
    end

    def to_s
      if positive
        @constraint.to_s
      else
        "not #{@constraint}"
      end
    end

    def invert
      self.class.new(@constraint, !@positive)
    end
    alias_method :inverse, :invert

    def intersect(other)
      raise ArgumentError, "packages must match" if package != other.package

      return self if relation(other) == :subset
      return other if other.relation(self) == :subset

      if positive? && other.positive?
        self.class.new(constraint.intersect(other.constraint), true)
      elsif negative? && other.negative?
        self.class.new(constraint.union(other.constraint), false)
      else
        positive = positive? ? self : other
        negative = negative? ? self : other
        self.class.new(positive.constraint.intersect(negative.constraint.invert), true)
      end
    end

    def difference(other)
      intersect(other.invert)
    end

    def relation(other)
      if positive? && other.positive?
        constraint.relation(other.constraint)
      elsif negative? && other.positive?
        if constraint.allows_all?(other.constraint)
          :disjoint
        else
          :overlap
        end
      elsif positive? && other.negative?
        if !other.constraint.allows_any?(constraint)
          :subset
        elsif other.constraint.allows_all?(constraint)
          :disjoint
        else
          :overlap
        end
      elsif negative? && other.negative?
        if constraint.allows_all?(other.constraint)
          :subset
        else
          :overlap
        end
      else
        raise
      end
    end

    def normalized_constraint
      @normalized_constraint ||= positive ? constraint : constraint.invert
    end

    def satisfies?(other)
      raise ArgumentError, "packages must match" unless package == other.package

      relation(other) == :subset
    end

    extend Forwardable
    def_delegators :@constraint, :package
    def_delegators :normalized_constraint, :versions, :constraint_string

    def positive?
      @positive
    end

    def negative?
      !positive?
    end

    def empty?
      @empty ||= normalized_constraint.empty?
    end

    def inspect
      "#<#{self.class} #{self}>"
    end
  end
end
