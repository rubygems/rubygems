if ENV['RUBYOPT'] or defined? Gem
  ENV.delete 'RUBYOPT'

  require 'rbconfig'
  cmd = [RbConfig.ruby, '--disable-gems', 'BUILD.rb', *ARGV]

  exec(*cmd)
end

$LOAD_PATH.unshift(File.expand_path("../../../../../lib", __FILE__))

require 'rubygems'
require 'rubygems/gem_runner'

fork do
  require 'tmpdir'

  Dir.mktmpdir("rust_ruby_example") do |dir|
    built_gem = File.join(dir, "rust_ruby_example.gem")
    Gem::GemRunner.new.run(["build", "rust_ruby_example.gemspec", "--output", built_gem])
    Gem::GemRunner.new.run(["install", "--verbose", built_gem, *ARGV])
  end
end

Process.wait

system %q(ruby -rrust_ruby_example -e "puts 'Result: ' + RustRubyExample.reverse('hello world')")
