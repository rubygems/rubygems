##
# Track Internet resources related to a gem.

class Gem::Resources
  include Enumerable

  ##
  # Valid URL (TODO: improve)

  URL = /^(http|https|ftp|mailto)\:\/\/.*?$/

  ##
  # Specail accessor stores values in a hash and can also handle hash 
  # key +aliases+.

  def self.attr_accessor(name, *aliases)
    list = ([name] + aliases).map{ |k| k.to_sym }
    list.each do |label|
      #list << list.shift until list.first == name
      define_method(label) do
        key = list.find{ |k| @table[k] } || label
        @table[key]
      end
      define_method("#{label}=") do |url|
        raise ArgumentError unless URL =~ url
        key = list.find{ |k| @table[k] } || label
        @table[key] = url
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
  # Project homepage.

  attr_accessor :home, :homepage

  ##
  # Source code browser.

  attr_accessor :code, :source, :source_code

  ##
  # Issue tracker.

  attr_accessor :bugs, :bug_tracker, :issues, :issue_tracker

  ##
  # Mialing list.

  attr_accessor :mail, :mailing_list

  ##
  # Documentation.

  attr_accessor :docs, :documentation

  ##
  # Wiki pages.

  attr_accessor :wiki

  ##
  # Support arbitrary resource labels.

  def method_missing(label, *args)
    case label.to_s
    when /=$/
      url = args.first
      raise ArgumentError unless URL =~ url
      label = label.to_s.chomp('=').to_sym
      @table[label] = url
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
  # Equality.

  def ==(other)
    self.class == other.class and @table == other.table
  end

  ##
  # Iterate over each label, url pair.

  def each(&block)
    @table.each(&block)
  end

  ##
  # Returns the number of reources.

  def size
    @table.size
  end

  protected

  attr :table

end
