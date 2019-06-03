# frozen_string_literal: true

require 'rubygems/test_case'
require 'rubygems/commands/web_command'

class TestGemCommandsWebCommand < Gem::TestCase

  def test_open_the_documentation
    VCR.use_cassette('documentation') do
      Launchy.expects(:open).with("http://api.rubyonrails.org")
      Gem::Web::Executor.new.open_page("rails", {doc: true})
    end
  end

  def test_open_the_homepage
    VCR.use_cassette('homepage') do
      Launchy.expects(:open).with("http://www.rubyonrails.org")
      Gem::Web::Executor.new.open_page("rails", {webpage: true})
    end
  end

  def test_open_the_source_code
    VCR.use_cassette('sourcecode') do
      Launchy.expects(:open).with("http://github.com/rails/rails")
      Gem::Web::Executor.new.open_page("rails", {sourcecode: true})
    end
  end

  def test_open_github
    VCR.use_cassette('github') do
      Launchy.expects(:open).with("http://github.com/rails/rails")
      Gem::Web::Executor.new.open_page("rails", {github: true})
    end
  end

  def test_open_rubygems
    Launchy.expects(:open).with("https://rubygems.org/gems/rails")
    Gem::Web::Executor.new.open_page("rails", {rubygems: true})
  end

  def test_open_rubytoolbox
    Launchy.expects(:open).with("https://www.ruby-toolbox.com/projects/rails")
    Gem::Web::Executor.new.open_page("rails", {rubytoolbox: true})
  end

  def test_search_unexisting_gem
    VCR.use_cassette('rubygems') do
      gem = ""
      assert_output(/Did not find #{gem} on rubygems.org\n/) { Gem::Web::Executor.new.open_page(gem, {}) }
    end
  end

  def test_open_rubygems_if_it_could_not_find_page
    Launchy.expects(:open).with("https://rubygems.org/gems/rails")
    assert_output("Did not find page for rails, opening RubyGems page instead.\n") do
      Gem::Web::Executor.new.launch_browser("rails", "")
    end
  end

end
