module Gem
  def self.sources_spec
    @sources_spec ||= Gem::Specification.new do |s|
      s.name = 'sources'
      s.version = "0.0.1"
      s.platform = Gem::Platform::RUBY
      s.summary = "This package provides download sources for remote gem installation"
      s.files = Dir.glob("lib/**/*").delete_if {|item| item.include?("CVS")}
      s.require_path = 'lib'
      s.autorequire = 'sources'
    end
  end
end

