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
  built_gem = "target/ruby_rutie_example.gem"
  Gem::GemRunner.new.run(["build", "rutie_ruby_example.gemspec", "--output", built_gem])
  Gem::GemRunner.new.run(["install", built_gem, "--install-dir", "target/gems"])
end

Process.wait

puts "Requiring gem..."
require_relative "./target/gems/gems/rutie_ruby_example-0.1.0/lib/rutie_ruby_example"

puts "Invoking RutieExample.reverse('hello world')..."
puts "Result: #{RutieExample.reverse("hello world")}"
