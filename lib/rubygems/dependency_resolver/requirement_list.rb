##
# Used internally to hold the requirements being considered
# while attempting to find a proper activation set.

class Gem::DependencyResolver::RequirementList

  def initialize
    @list = []
  end

  def initialize_copy(other)
    @list = @list.dup
  end

  def add(req)
    @list.push req
    req
  end

  def empty?
    @list.empty?
  end

  def remove
    @list.shift
  end
end
