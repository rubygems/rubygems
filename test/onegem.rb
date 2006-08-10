#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

module OneGem

  ONEDIR = "test/data/one"
  ONENAME = "one-0.0.1.gem"
  ONEGEM = "#{ONEDIR}/#{ONENAME}"

  def clear
    FileUtils.rm_f ONEGEM
  end

  def make(controller)
    unless File.exist?(ONEGEM)
      build(controller)
    end
  end

  def build(controller)
    Dir.chdir(ONEDIR) do
      controller.gem "build one.gemspec"
    end
  end

  def rebuild(controller)
    clear
    build(controller)
  end

  extend self
end
