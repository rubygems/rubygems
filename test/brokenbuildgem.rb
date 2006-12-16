#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

module BrokenBuildGem

  DIR = "test/data/broken_build"
  NAME = "broken-build-0.0.1.gem"
  GEM = "#{DIR}/#{NAME}"

  def clear
    FileUtils.rm_f GEM
  end

  def make(controller)
    unless File.exist?(GEM)
      build(controller)
    end
  end

  def build(controller)
    Dir.chdir(DIR) do
      controller.gem "build broken-build.gemspec"
    end
  end
  
  def install(controller)
    make(controller)
    controller.gem "install #{GEM}"
  end

  extend self
end
