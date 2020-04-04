# frozen_string_literal: true
require 'rubygems/command'
require 'erb'

class Gem::Ext::CmakeBuilder < Gem::Ext::Builder

  def self.generate(erb_path)
    tpl = File.read erb_path
    erb = ERB.new tpl
    erb.result binding
  end

  def self.build(extension, dest_path, results, args=[], lib_dir=nil)
    if !File.exist?('CMakeLists.txt') && File.exist?('CMakeLists.txt.erb')
      File.open('CMakeLists.txt', 'w') { |f| f.write generate('CMakeLists.txt.erb') }
    end

    unless File.exist?('Makefile')
      cmd = +"cmake . -DCMAKE_INSTALL_PREFIX=#{dest_path}"
      cmd << " -G \"NMake Makefiles\"" if /mswin/ =~ RUBY_PLATFORM
      cmd << " -DCMAKE_BUILD_TYPE=Release" unless /\-DCMAKE_BUILD_TYPE/ =~ Gem::Command.build_args.join
      cmd << " #{Gem::Command.build_args.join ' '}" unless Gem::Command.build_args.empty?

      run cmd, results
    end

    make dest_path, results

    results
  end

end
