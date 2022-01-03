if ENV['RUBYOPT'] or defined? Gem
  ENV.delete 'RUBYOPT'

  require 'rbconfig'
  cmd = [RbConfig.ruby, '--disable-gems', 'BUILD.rb', *ARGV]

  exec(*cmd)
end

$LOAD_PATH.unshift(File.expand_path("../../../../../lib", __FILE__))

require 'rubygems'
require 'rubygems/gem_runner'

dest_path = ARGV.first || "target"

fork do
  built_gem = File.join(dest_path, "rust_ruby_example.gem")
  Gem::GemRunner.new.run(["build", "rust_ruby_example.gemspec", "--output", built_gem])
  Gem::GemRunner.new.run(["install", built_gem, "--install-dir", dest_path])
end

Process.wait

ext = Dir["#{dest_path}/**/rust_ruby_example.{so,bundle}"].first

puts "Requiring gem..."
require File.expand_path(ext).gsub(".bundle", "")

puts "Invoking RustRubyExample.reverse('hello world')..."
puts "Result: #{RustRubyExample.reverse("hello world")}"
