require 'forwardable'
require 'thread'

require 'hamster/core_ext/enumerable'
require 'hamster/undefined'
require 'hamster/enumerable'
require 'hamster/tuple'
require 'hamster/sorter'
require 'hamster/hash'
require 'hamster/set'

module Hamster

  class << self

    extend Forwardable

    def list(*items)
      items.to_list
    end

    def stream(&block)
      return EmptyList unless block_given?
      Stream.new { Sequence.new(yield, stream(&block)) }
    end

    def interval(from, to)
      return EmptyList if from > to
      interval_exclusive(from, to.next)
    end
    def_delegator :self, :interval, :range

    def repeat(item)
      Stream.new { Sequence.new(item, repeat(item)) }
    end

    def replicate(number, item)
      repeat(item).take(number)
    end

    def iterate(item, &block)
      Stream.new { Sequence.new(item, iterate(yield(item), &block)) }
    end

    private

    def interval_exclusive(from, to)
      return EmptyList if from == to
      Stream.new { Sequence.new(from, interval_exclusive(from.next, to)) }
    end

  end

  module List

    extend Forwardable

    include Enumerable

    CADR = /^c([ad]+)r$/

    def_delegator :self, :head, :first

    def_delegator :self, :empty?, :null?

    def size
      reduce(0) { |memo, item| memo.next }
    end
    def_delegator :self, :size, :length

    def cons(item)
      Sequence.new(item, self)
    end
    def_delegator :self, :cons, :>>

    def each
      return self unless block_given?
      list = self
      while !list.empty?
        yield(list.head)
        list = list.tail
      end
    end

    def map(&block)
      return self unless block_given?
      Stream.new do
        next self if empty?
        Sequence.new(yield(head), tail.map(&block))
      end
    end
    def_delegator :self, :map, :collect

    def filter(&block)
      return self unless block_given?
      Stream.new do
        next self if empty?
        next Sequence.new(head, tail.filter(&block)) if yield(head)
        tail.filter(&block)
      end
    end

    def take_while(&block)
      return self unless block_given?
      Stream.new do
        next self if empty?
        next Sequence.new(head, tail.take_while(&block)) if yield(head)
        EmptyList
      end
    end

    def drop_while(&block)
      return self unless block_given?
      Stream.new do
        list = self
        while !list.empty? && yield(list.head)
          list = list.tail
        end
        list
      end
    end

    def take(number)
      Stream.new do
        next self if empty?
        next Sequence.new(head, tail.take(number - 1)) if number > 0
        EmptyList
      end
    end

    def drop(number)
      Stream.new do
        list = self
        while !list.empty? && number > 0
          number -= 1
          list = list.tail
        end
        list
      end
    end

    def append(other)
      Stream.new do
        next other if empty?
        Sequence.new(head, tail.append(other))
      end
    end
    def_delegator :self, :append, :concat
    def_delegator :self, :append, :cat
    def_delegator :self, :append, :+

    def reverse
      Stream.new { reduce(EmptyList) { |list, item| list.cons(item) } }
    end

    def zip(other)
      Stream.new do
        next self if empty? && other.empty?
        Sequence.new(Sequence.new(head, Sequence.new(other.head)), tail.zip(other.tail))
      end
    end

    def cycle
      Stream.new do
        next self if empty?
        Sequence.new(head, tail.append(self.cycle))
      end
    end

    def split_at(number)
      Tuple.new(take(number), drop(number))
    end

    def span(&block)
      return Tuple.new(self, EmptyList) unless block_given?
      Tuple.new(take_while(&block), drop_while(&block))
    end

    def break(&block)
      return span unless block_given?
      span { |item| !yield(item) }
    end

    def clear
      EmptyList
    end

    def sort(&comparator)
      Stream.new { Sorter.new(self).sort(&comparator) }
    end

    def sort_by(&transformer)
      return sort unless block_given?
      Stream.new { Sorter.new(self).sort_by(&transformer) }
    end

    def join(sep = "")
      return "" if empty?
      sep = sep.to_s
      tail.reduce(head.to_s.dup) { |result, item| result << sep << item.to_s }
    end

    def intersperse(sep)
      Stream.new do
        next self if tail.empty?
        Sequence.new(head, Sequence.new(sep, tail.intersperse(sep)))
      end
    end

    def uniq(items = EmptySet)
      Stream.new do
        next self if empty?
        next tail.uniq(items) if items.include?(head)
        Sequence.new(head, tail.uniq(items.add(head)))
      end
    end
    def_delegator :self, :uniq, :nub
    def_delegator :self, :uniq, :remove_duplicates

    def union(other)
      self.append(other).uniq
    end
    def_delegator :self, :union, :|

    def init
      return EmptyList if tail.empty?
      Stream.new { Sequence.new(head, tail.init) }
    end

    def last
      list = self
      while !list.tail.empty?
        list = list.tail
      end
      list.head
    end

    def tails
      Stream.new do
        next Sequence.new(self) if empty?
        Sequence.new(self, tail.tails)
      end
    end

    def inits
      Stream.new do
        next Sequence.new(self) if empty?
        Sequence.new(EmptyList, tail.inits.map { |list| list.cons(head) })
      end
    end

    def combinations(number)
      return Sequence.new(EmptyList) if number == 0
      Stream.new do
        next self if empty?
        tail.combinations(number - 1).map { |list| list.cons(head) }.append(tail.combinations(number))
      end
    end
    def_delegator :self, :combinations, :combination

    def chunk(number)
      Stream.new do
        next self if empty?
        first, remainder = split_at(number)
        Sequence.new(first, remainder.chunk(number))
      end
    end

    def each_chunk(number, &block)
      chunk(number).each(&block)
    end
    def_delegator :self, :each_chunk, :each_slice

    def flatten
      Stream.new do
        next self if empty?
        next head.append(tail.flatten) if head.is_a?(List)
        Sequence.new(head, tail.flatten)
      end
    end

    def group_by(&block)
      return group_by { |item| item } unless block_given?
      reduce(EmptyHash) do |hash, item|
        key = yield(item)
        hash.put(key, (hash.get(key) || EmptyList).cons(item))
      end
    end
    def_delegator :self, :group_by, :group

    def at(index)
      drop(index).head
    end

    def slice(from, length = Undefined)
      return at(from) if length.equal?(Undefined)
      drop(from).take(length)
    end
    def_delegator :self, :slice, :[]

    def find_index
      return nil unless block_given?
      i = 0
      list = self
      loop do
        return nil if list.empty?
        return i if yield(list.head)
        i += 1
        list = list.tail
      end
    end

    def elem_index(object)
      find_index { |item| item == object }
    end

    def index(object = Undefined, &block)
      return elem_index(object) unless object.equal?(Undefined)
      find_index(&block)
    end

    def find_indices(i = 0, &block)
      return EmptyList unless block_given?
      Stream.new do
        next EmptyList if empty?
        next Sequence.new(i, tail.find_indices(i + 1, &block)) if yield(head)
        tail.find_indices(i + 1, &block)
      end
    end

    def elem_indices(object)
      find_indices { |item| item == object }
    end

    def indices(object = Undefined, &block)
      return elem_indices(object) unless object.equal?(Undefined)
      find_indices(&block)
    end

    def merge(&comparator)
      return merge_by unless block_given?
      Stream.new do
        sorted = remove(&:empty?).sort do |a, b|
          yield(a.head, b.head)
        end
        next EmptyList if sorted.empty?
        Sequence.new(sorted.head.head, sorted.tail.cons(sorted.head.tail).merge(&comparator))
      end
    end

    def merge_by(&transformer)
      return merge_by { |item| item } unless block_given?
      Stream.new do
        sorted = remove(&:empty?).sort_by do |list|
          yield(list.head)
        end
        next EmptyList if sorted.empty?
        Sequence.new(sorted.head.head, sorted.tail.cons(sorted.head.tail).merge_by(&transformer))
      end
    end

    def eql?(other)
      list = self
      loop do
        return true if other.equal?(list)
        return false unless other.is_a?(List)
        return other.empty? if list.empty?
        return false if other.empty?
        return false unless other.head.eql?(list.head)
        list = list.tail
        other = other.tail
      end
    end
    def_delegator :self, :eql?, :==

    def hash
      reduce(0) { |hash, item| (hash << 5) - hash + item.hash }
    end

    def dup
      self
    end
    def_delegator :self, :dup, :clone

    def to_list
      self
    end

    def to_set
      reduce(EmptySet) { |set, item| set.add(item) }
    end

    def inspect
      to_a.inspect
    end

    def respond_to?(name, include_private = false)
      super || CADR === name.to_s
    end

    private

    def method_missing(name, *args, &block)
      return accessor($1) if CADR === name.to_s
      super
    end

    # Perform compositions of <tt>car</tt> and <tt>cdr</tt> operations. Their names consist of a 'c', followed by at
    # least one 'a' or 'd', and finally an 'r'. The series of 'a's and 'd's in each function's name is chosen to
    # identify the series of car and cdr operations that is performed by the function. The order in which the 'a's and
    # 'd's appear is the inverse of the order in which the corresponding operations are performed.
    def accessor(sequence)
      sequence.reverse.each_char.reduce(self) do |memo, char|
        case char
        when "a" then memo.head
        when "d" then memo.tail
        end
      end
    end

  end

  class Sequence

    include List

    attr_reader :head, :tail

    def initialize(head, tail = EmptyList)
      @head = head
      @tail = tail
    end

    def empty?
      false
    end

  end

  class Stream

    extend Forwardable

    include List

    def initialize(&block)
      @block = block
      @lock = Mutex.new
    end

    def_delegator :target, :head
    def_delegator :target, :tail
    def_delegator :target, :empty?

    protected

    def vivify
      @lock.synchronize do
        unless @block.nil?
          @target = @block.call
          @block = nil
        end
      end
      @target
    end

    private

    def target
      list = vivify
      while list.is_a?(Stream)
        list = list.vivify
      end
      list
    end

  end

  module EmptyList

    class << self

      include List

      def head
        nil
      end

      def tail
        self
      end

      def empty?
        true
      end

    end

  end

end
