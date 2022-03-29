# frozen_string_literal: true

require 'pathname'

def source_root
  @source_root ||= Pathname.new("../..").expand_path(__dir__)
end

def test_dir
  @test_dir ||= source_root.join('test')
end

def test_rubygems_dir
  @test_rubygems_dir ||= test_dir.join('rubygems')
end
