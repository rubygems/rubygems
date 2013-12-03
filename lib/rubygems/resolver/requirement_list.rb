##
# Used internally to hold the requirements being considered
# while attempting to find a proper activation set.

class Gem::Resolver::RequirementList

  include Enumerable

  def initialize
    @exact = []
    @list = []
  end

  def initialize_copy(other)
    @exact = @exact.dup
    @list = @list.dup
  end

  def add(req)
    if req.requirement.exact?
      @exact.push req
    else
      @list.push req
    end
    req
  end

  ##
  # Enumerates requirements in the list

  def each # :nodoc:
    return enum_for __method__ unless block_given?

    @exact.each do |requirement|
      yield requirement
    end

    @list.each do |requirement|
      yield requirement
    end
  end

  def size
    @exact.size + @list.size
  end

  def empty?
    @exact.empty? && @list.empty?
  end

  def remove
    return @exact.shift unless @exact.empty?
    @list.shift
  end

  def next5
    x = @exact[0,5]
    x + @list[0,5 - x.size]
  end
end
