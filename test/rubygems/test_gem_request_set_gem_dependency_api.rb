require 'rubygems/test_case'
require 'rubygems/request_set'

class TestGemRequestSetGemDependencyAPI < Gem::TestCase

  def setup
    super

    @GDA = Gem::RequestSet::GemDepedencyAPI

    @set = Gem::RequestSet.new
  end

  def test_load
    Tempfile.open 'Gemfile' do |io|
      io.puts 'gem "rake", "~> 10.1"'
      io.flush

      gda = @GDA.new @set, io.path

      gda.load

      expected = [
        dep('rake', '~> 10.1')
      ]

      assert_equal expected, @set.dependencies
    end
  end

end

