require 'test/unit'
require 'rubygems'

class Versions < Test::Unit::TestCase

  WRONG_NUMS = [
    "blah", "1.3.a", "1.3.5."
  ]

  WRONG_REQS = [
    ">>> 1.3.5", "> blah"
  ]

  OK = [
                # Required	Given
        [	"= 0.2.33",	"0.2.33"	],
        [	"> 0.2.33",	"0.2.34"	],
        [	"= 1.0",	"1.0"		],
        [	"1.0",	"1.0"		],
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

