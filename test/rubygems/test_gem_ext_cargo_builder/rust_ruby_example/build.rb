# if ENV['RUBYOPT'] or defined? Gem
#   ENV.delete 'RUBYOPT'

#   require 'rbconfig'
#   cmd = [RbConfig.ruby, '--disable-gems', 'BUILD.rb', *ARGV]

#   exec(*cmd)
# end

lp = File.expand_path("../../../../../lib", __FILE__)

require 'tmpdir'

Dir.mktmpdir("rust_ruby_example") do |dir|
  built_gem = File.expand_path(File.join(dir, "rust_ruby_example.gem"))
  gem = ["ruby", "-I#{lp}", File.expand_path("../../../../../bin/gem", __FILE__)]
  system *gem, "build", "rust_ruby_example.gemspec", "--output", built_gem
  system *gem, "install", "--verbose", "--local", built_gem, *ARGV
  system %q(ruby -rrust_ruby_example -e "puts 'Result: ' + RustRubyExample.reverse('hello world')")
end
