module Gem

  class Dependency
    attr_accessor :name, :version_requirement
    def initialize(name, version_requirement)
      @name = name
      @version_requirement = Version::Requirement.new(version_requirement)
    end
  end
  
  class Version
    attr_accessor :version
    
    def initialize(version)
      raise ArgumentError, 
            "Malformed version number string #{version}" unless correct?(version)
      @version = version
    end
    
    def to_s
      @version
    end
    
    include Comparable

    NUM_RE = /\s*(\d+(\.\d+)*)*\s*/

    def correct?(str)
      /^#{NUM_RE}$/.match(str)
    end

    def to_ints
      @version.scan(/\d+/).map {|s| s.to_i}
    end

    def <=>(other)
      rnums, vnums = to_ints, other.to_ints
      [rnums.size, vnums.size].max.times {|i|
        rnums[i] ||= 0
        vnums[i] ||= 0
      }
      
      begin
        r,v = rnums.shift, vnums.shift
      end until (r != v || rnums.empty?)

      return r <=> v
    end
    
    class Requirement < Version
      REQ_RE = /\s*(\D\D?)\s*/
  
      EQ = 0
      GT = 1
      LT = -1
  
      def correct?(str)
        /^#{REQ_RE}#{NUM_RE}$/.match(str)
      end
  
      def initialize(str)
        super
        @op, @nums = parse
      end
  
      def satisfied_by?(vn)
        ops = {
                "=" =>  [ EQ ],
                "!=" => [ GT, LT ],
                ">" =>  [ GT ],
                "<" =>  [ LT ],
                ">=" => [ EQ, GT ],
                "<=" => [ EQ, LT ]
        }
        
        state = vn <=> self
        ops[@op].include?(state)
      end
  
      private
      def parse
        return @version.scan(/^\D+/).join.strip,
                @version.scan(/\d+/).map {|s| s.to_i}
      end
    end
  end
end
