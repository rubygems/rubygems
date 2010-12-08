##
# Track Internet resources related to a gem.

class Gem::Resources

  ##
  # Specail accessor stores values in a hash and can also handle hash 
  # key +aliases+.

  def self.attr_accessor(name, *aliases)
    list = [name] + aliases
    list.each do |label|
      #list << list.shift until list.first == name
      define_method(label) do
        key = list.find{ |k| @table[k.to_sym] } || label
        @table[key.to_sym]
      end
      define_method("#{label}=") do |value|
        key = list.find{ |k| @table[k.to_sym] } || label
        @table[key.to_sym] = value
      end
    end
  end

  ##
  # Create new Resources instance. A Hash of <code>label => url</code>
  # can be passed as +resources+.

  def initialize(resources={})
    @table = {}
    resources.each do |label,url|
      add_resource(label, url)
    end
  end

  ##
  # Add a new resource.
  #
  # Internally the +label+ is stored as a Symbol.
  #
  # TODO: validate URL ?

  def add_resource(label, url)
    __send__("#{label}=", url)
  end

  ##
  # Convert Resource to a Hash.

  def to_h
    @table.inject({}) do |h,(k,v)|
      h[k.to_s] = v; h
    end
  end

  ##
  #

  attr_accessor :home, :homepage

  ##
  #

  attr_accessor :code, :source, :source_code

  ##
  #

  attr_accessor :bugs, :bug_tracker, :issues, :issue_tracker

  ##
  #

  attr_accessor :mail, :mailing_list

  ##
  #

  attr_accessor :docs, :documentation

  ##
  #

  attr_accessor :wiki

  ##
  # Support arbitrary resource labels.

  def method_missing(label, *a, &b)
    case label.to_s
    when /=$/
      set(label.to_s.chomp('='), a.first)
    else
      @table[label]
    end
  end

  ##
  # A resources's hash is the hash of the underlying table.

  def hash # :nodoc:
    @table.hash
  end

  ##
  #

  def ==(other)
    self.class == other.class and @table == other.table
  end

  ##
  #

  def eql?(other)
    self.class == other.class and @table.eql?(other.table)
  end

  #
  def each(&block)
    @table.each(&block)
  end

  protected

  attr :table

  private

  def set(label, url)
    @table[label.to_sym] = url
  end

end

