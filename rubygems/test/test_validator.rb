require 'test/unit'
require 'rubygems'

class TestValidator < Test::Unit::TestCase
  def test_missing_gem_throws_error
    assert_raise(Gem::VerificationError) {
      Gem::Validator.new.verify_gem_file("")
    }
  end

  def test_invalid_gem_throws_error
    assert_raise(Gem::VerificationError) {
      Gem::Validator.new.verify_gem("")
    }
  end

  def test_simple_valid_gem_verifies
    assert_nothing_raised {
      Gem::Validator.new.verify_gem(@simple_gem)
    }
  end

  def test_truncated_simple_valid_gem_fails
    assert_raise(Gem::VerificationError) {
      Gem::Validator.new.verify_gem(@simple_gem.chop)
    }
  end

  def setup
    @simple_gem = <<-GEMDATA
        MD5SUM = "0dcd2b17ea9bc29a1a3a73785e658ef6"
        if $0 == __FILE__
          require 'optparse'
        
          options = {}
          ARGV.options do |opts|
            opts.on_tail("--help", "show this message") {puts opts; exit}
            opts.on('--dir=DIRNAME', "Installation directory for the Gem") {|options[:directory]|}
            opts.on('--force', "Force Gem to intall, bypassing dependency checks") {|options[:force]|}
            opts.on('--gen-rdoc', "Generate RDoc documentation for the Gem") {|options[:gen_rdoc]|}
            opts.parse!
          end

          require 'rubygems'
          @directory = options[:directory] || Gem.dir  
          @force = options[:force]
  
          gem = Gem::Installer.new(__FILE__).install(@force, @directory)      
          if options[:gen_rdoc]
            Gem::DocManager.new(gem).generate_rdoc
          end
end

__END__
--- !ruby/object:Gem::Specification 
rubygems_version: "1.0"
name: simple
version: !ruby/object:Gem::Version 
  version: 1.2.3
date: 2004-03-28 11:53:31.494975 -05:00
platform: 
summary: simple
require_paths: 
files: []
--- []
    GEMDATA
  end
end
