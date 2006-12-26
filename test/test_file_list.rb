#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'fileutils'
require 'tmpdir'
require 'test/unit'
require 'rubygems'
require 'test/gemutilities'
Gem::manage_gems

class TestFileList < RubyGemTestCase

    def import_spec(name)
      file = File.join(@gem_install_path, "specifications", name)
      eval File.read(file)
    end

    def setup
      @spec = Gem::Specification.new do |s|
        s.files = ['lib/code.rb','lib/apple.rb','lib/brown.rb']
        s.name = "a"
        s.version = "0.0.1"
        s.summary = "summary"
        s.description = "desc"
        s.require_path = 'lib'
      end
      
      @cm = Gem::CommandManager.new
      @contents = @cm['contents']
      
      current_path = Dir.getwd
      @gem_install_path =  File.join(current_path, "test/mock/gems/")
      @gem_root_dir = File.join(@gem_install_path, "gems", @spec.name + "-" + @spec.version.to_s)
      
      @gemspec_filename = @spec.name + '-' + @spec.version.to_s + '.gemspec'
      @spec_destination_path = File.join(@gem_install_path, "specifications", @gemspec_filename)
      
      begin
        File.open(@spec_destination_path, 'w') do |fp| 
          fp.write @spec.to_ruby
        end
      rescue Exception => e 
        # ignore errors in setup
      end
      
    end
    
    def teardown
      FileUtils.rm_rf @spec_destination_path unless $DEBUG
    end
    
    def test_inspect_list
        args = ["-s", @gem_install_path, "a"]
        Gem::Command.instance_eval "public :handle_options"
        @contents.handle_options(args)
        sio = StringIO.new
        @contents.execute(sio)
        files = sio.string.split("\n")
        code = File.join(@gem_root_dir,"lib/code.rb")
        assert_match(code, files[0])
    end

    def test_inspect_list_unknown
        args = ["-s", @gem_install_path, "not_there"]
        Gem::Command.instance_eval "public :handle_options"
        @contents.handle_options(args)
        sio = StringIO.new
        @contents.execute(sio)
        assert_match(/Unable to find/, sio.string)
    end

    def disable_test_specification



        puts "  dest path: " + @spec_destination_path
        assert(FileTest.exists?(@spec_destination_path))
        assert(FileTest.size(@spec_destination_path)>0)
        spec = import_spec(@gemspec_filename)

        p spec.require_paths
        p spec.full_gem_path

        files = spec.files.map do |f|
        end

        root = @gem_install_path + "a-0.0.1";

        puts "  files[0] is: " + files[0]

        check1 = root + "/lib/code.rb"
        puts "  check1 is " + check1
        assert(files[0] == check1)
        assert(files[1] == root + "/lib/apple.rb");
        assert(files[2] == root + "/lib/brown.rb");
    end

end
