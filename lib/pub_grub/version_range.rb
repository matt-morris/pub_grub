# frozen_string_literal: true

module PubGrub
  class VersionRange
    attr_reader :min, :max, :include_min, :include_max

    alias_method :include_min?, :include_min
    alias_method :include_max?, :include_max

    class Empty < VersionRange
      undef_method :min, :max
      undef_method :include_min, :include_min?
      undef_method :include_max, :include_max?

      def initialize
      end

      def empty?
        true
      end

      def intersects?(_)
        false
      end

      def include?(_)
        false
      end

      def any?
        false
      end

      def constraints
        ["(no versions)"]
      end

      def ==(other)
        other.class == self.class
      end
    end

    def self.empty
      Empty.new
    end

    class Union
      attr_reader :ranges

      def initialize(ranges)
        @ranges = ranges.flat_map do |range|
          if range.is_a?(Union)
            range.ranges
          else
            [range]
          end
        end
      end

      def include?(version)
        ranges.any? { |r| r.include?(version) }
      end

      def intersects?(other)
        ranges.any? { |r| r.intersects?(other) }
      end

      def empty?
        ranges.all?(&:empty?)
      end

      def intersect(other)
        new_ranges = ranges.map{ |r| r.intersect(other) }
        new_ranges.reject!(&:empty?)
        if new_ranges.empty?
          VersionRange.empty
        else
          self.class.new(new_ranges)
        end
      end

      def invert
        ranges.map(&:invert).inject(:intersect)
      end
    end

    def self.any
      new
    end

    def initialize(min: nil, max: nil, include_min: false, include_max: false)
      @min = min
      @max = max
      @include_min = include_min
      @include_max = include_max

      if min && max
        if min > max
          raise ArgumentError, "min version #{min} must be less than max #{max}"
        elsif min == max && (!include_min || !include_max)
          raise ArgumentError, "include_min and include_max must be true when min == max"
        end
      end
    end

    def include?(version)
      if min
        return false if version < min
        return false if !include_min && version == min
      end

      if max
        return false if version > max
        return false if !include_max && version == max
      end

      true
    end

    def strictly_lower?(other)
      return false if !max || !other.min

      case max <=> other.min
      when 0
        !include_max || !other.include_min
      when -1
        true
      when 1
        false
      end
    end

    def strictly_higher?(other)
      other.strictly_lower?(self)
    end

    def intersects?(other)
      return false if other.empty?
      return other.intersects?(self) if other.is_a?(Union)
      !strictly_lower?(other) && !strictly_higher?(other)
    end

    def intersect(other)
      return self.class.empty unless intersects?(other)
      return other.intersect(self) if other.is_a?(Union)

      min_range =
        if !min
          other
        elsif !other.min
          self
        else
          case min <=> other.min
          when 0
            include_min ? other : self
          when -1
            other
          when 1
            self
          end
        end

      max_range =
        if !max
          other
        elsif !other.max
          self
        else
          case max <=> other.max
          when 0
            include_max ? other : self
          when -1
            self
          when 1
            other
          end
        end

      self.class.new(
        min: min_range.min,
        include_min: min_range.include_min,
        max: max_range.max,
        include_max: max_range.include_max
      )
    end

    def union(other)
      Union.new([self, other])
    end

    def constraints
      return ["any"] if any?
      return ["= #{min}"] if min == max

      c = []
      c << "#{include_min ? ">=" : ">"} #{min}" if min
      c << "#{include_max ? "<=" : "<"} #{max}" if max
      c
    end

    def any?
      !min && !max
    end

    def empty?
      false
    end

    def to_s
      constraints.join(", ")
    end

    def inspect
      "#<#{self.class} #{to_s}>"
    end

    def invert
      return self.class.empty if any?

      low = VersionRange.new(max: min, include_max: !include_min)
      high = VersionRange.new(min: max, include_min: !include_max)

      if !min
        high
      elsif !max
        low
      else
        low.union(high)
      end
    end

    def ==(other)
      self.class == other.class &&
        min == other.min &&
        max == other.max &&
        include_min == other.include_min &&
        include_max == other.include_max
    end
  end
end