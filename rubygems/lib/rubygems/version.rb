module Gem

  class Dependency
    attr_accessor :name, :version_requirement
    def initialize(name, version_requirement)
      @name = name
      @version_requirement = Version::Requirement.new(version_requirement)
    end
  end
  
  class Version
    include Comparable

    attr_accessor :version

    NUM_RE = /\s*(\d+(\.\d+)*)*\s*/
    
    def initialize(version)
      raise ArgumentError, 
        "Malformed version number string #{version}" unless correct?(version)
      @version = version
    end
    
    def to_s
      @version
    end
    
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
  
      EQ = 0
      GT = 1
      LT = -1
  
      OPS = {
              "=" =>  [ EQ ],
              "!=" => [ GT, LT ],
              ">" =>  [ GT ],
              "<" =>  [ LT ],
              ">=" => [ EQ, GT ],
              "<=" => [ EQ, LT ]
      }
        
      OP_RE = Regexp.new(OPS.keys.join("|"))
      REQ_RE = /\s*(#{OP_RE})\s*/

      def correct?(str)
        /^#{REQ_RE}#{NUM_RE}$/.match(str)
      end

      def initialize(str)
        super
        @op, @nums = parse
      end
  
      def satisfied_by?(vn)
        relation = vn <=> self
        OPS[@op].include?(relation)
      end
  
      private
      def parse
        return @version.scan(/^\D+/).join.strip,
               @version.scan(/\d+/).map {|s| s.to_i}
      end
    end
  end
end

if __FILE__ == $0

require 'test/unit'
class Versions < Test::Unit::TestCase

  WRONG_NUMS = [
    "blah", "1.3.a", "1.3.5."
  ]

  WRONG_REQS = [
    "2.3.4", ">>> 1.3.5", "> blah"
  ]

  OK = [
                # Required	Given
        [	"= 0.2.33",	"0.2.33"	],
        [	"> 0.2.33",	"0.2.34"	],
        [	"= 1.0",	"1.0"		],
        [	"> 1.8.0",	"1.8.2"		],
        [	"> 1.111", 	"1.112"		],
        [	"> 0.0.0", 	"0.2"		],
        [	"> 0.0.0", 	"0.0.0.0.0.2"	],
        [	"> 0.0.0.1", 	"0.0.1.0"	],
        [	"> 9.3.2", 	"10.3.2"	],
        [	"= 1.0", 	"1.0.0.0"	],
        [	"!= 9.3.4", 	"10.3.2"	],
        [	"> 9.3.2", 	"10.3.2"	],
        [	"> 9.3.2", 	"10.3.2"	],
        [	">= 9.3.2", 	" 9.3.2"        ],
        [	">= 9.3.2", 	"9.3.2 "        ],
        [       "= 0",          ""              ],
        [       "< 0.1",        ""              ], 
        [       "< 0.1 ",        "  "           ], 
        [       " <  0.1",        ""            ], 
        [       "=",            "0"             ], 
        [       ">=",            "0"            ], 
        [       "<=",            "0"            ], 
  ]

  BAD = [
             # Required      Given
         [      "> 0.1",        ""              ], 
         [      "!= 1.2.3",      "1.2.3"        ],
         [      "!= 1.02.3",      "1.2.003.0.0" ],
         [      "< 1.2.3",      "4.5.6"         ],
         [	"> 1.1",	"1.0"		],
         [      ">",            "0"             ], 
         [      "<",            "0"             ], 
         [      "= 0.1",        ""              ], 
         [	"> 1.1.1",	"1.1.1"		],
         [	"= 1.1",	"1.2"		],
         [	"= 1.1",	"1.40"		],
         [	"= 1.40",	"1.3"		],
         [	"<= 9.3.2", 	"9.3.3"	        ],
         [	">= 9.3.2", 	"9.3.1"	        ],
         [	"<= 9.3.2", 	"9.3.03"        ],
         [	"= 1.0", 	"1.0.0.1"	],
  ]

  i = 0
  WRONG_NUMS.each do |wn|
    class_eval <<-EOE
    def test_wn_#{i}
      assert_raises(ArgumentError) { Gem::Version.new(\"#{wn}\") }
    end
EOE
  i += 1
end

  i = 0
  WRONG_REQS.each do |wn|
    class_eval <<-EOE
    def test_wn_#{i}
      assert_raises(ArgumentError) { Gem::Version::Requirement.new(\"#{wn}\") }
    end
EOE
  i += 1
end

  i = 0
  OK.each do |ok|
    class_eval <<-EOE
    def test_ok_#{i}   
      r = Gem::Version::Requirement.new(\"#{ok[0]}\")
      v = Gem::Version.new(\"#{ok[1]}\")
      assert(r.satisfied_by?(v),"Bad: \#{r}, \#{v}")
    end
EOE
  i += 1
  end

  i = 0
  BAD.each do |bad|
    class_eval <<-EOE
    def test_bad_#{i}   
      r = Gem::Version::Requirement.new(\"#{bad[0]}\")
      v = Gem::Version.new(\"#{bad[1]}\")
      assert(!r.satisfied_by?(v), "Good: \#{r.to_ints}, \#{v.to_ints}")
    end
EOE
  i += 1
  end
end

end
