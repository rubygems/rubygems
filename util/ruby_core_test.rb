# frozen_string_literal: true

# From ruby/ruby, copies tool/lib files
# Replicates testing used in Ruby master

require 'uri'
require 'net/http'
require 'openssl'
require 'fileutils'

module HTTPS_DL

  # number of concurrent connections
  CONNECTIONS = 4

  HOST = "https://raw.githubusercontent.com"
  URI_GH = URI HOST
  BASE = "ruby/ruby/master"

  # 1st - directory       , 2nd - filename
  FILES = [
    ["test"               , "runner.rb"              ],
    ["tool/lib"           , "colorize.rb"            ],
    ["tool/lib"           , "envutil.rb"             ],
    ["tool/lib"           , "find_executable.rb"     ],
    ["tool/lib"           , "gc_compact_checker.rb"  ],
    ["tool/lib"           , "iseq_loader_checker.rb" ],
    ["tool/lib"           , "leakchecker.rb"         ],
    ["tool/lib"           , "tracepointchecker.rb"   ],
    ["tool/lib"           , "zombie_hunter.rb"       ],
    ["tool/lib/minitest"  , "autorun.rb"             ],
    ["tool/lib/minitest"  , "benchmark.rb"           ],
    ["tool/lib/minitest"  , "mock.rb"                ],
    ["tool/lib/minitest"  , "unit.rb"                ],
    ["tool/lib/test"      , "unit.rb"                ],
    ["tool/lib/test/unit" , "assertions.rb"          ],
    ["tool/lib/test/unit" , "core_assertions.rb"     ],
    ["tool/lib/test/unit" , "parallel.rb"            ],
    ["tool/lib/test/unit" , "testcase.rb"            ],
    ["tool/test"          , "runner.rb"              ]
  ]

  class << self

    def run
      files = FILES

      dirs = FILES.map { |l| l[0] }.uniq
      dirs.each { |dir| FileUtils.mkdir_p("./#{dir}") unless Dir.exist? dir }

      connections = []

      CONNECTIONS.times do
        connections << Thread.new do
          Net::HTTP.start(URI_GH.host, URI_GH.port, :use_ssl => true,:verify_mode => OpenSSL::SSL::VERIFY_PEER) do |http|
            while (dir, file = files.shift)
              uri = URI("#{HOST}/#{BASE}/#{dir}/#{file}")
              req = Net::HTTP::Get.new uri.request_uri
              http.request req do |res|
                unless Net::HTTPOK === res
                  STDOUT.puts "Can't download #{dir}/#{file} from #{HOST}/#{BASE}/"
                  exit 1
                end
                File.write "./#{dir}/#{file}", res.body, mode: 'wb', encoding: "UTF-8"
              end
            end
          end
        end
      end
      connections.each { |th| th.join }
    end
  end
end

HTTPS_DL.run
