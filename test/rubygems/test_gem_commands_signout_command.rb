# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/commands/signout_command'
require 'rubygems/installer'

class TestGemCommandsSignoutCommand < Gem::TestCase

  def setup
    super
    @cmd = Gem::Commands::SignoutCommand.new
  end

  def teardown
    super
    File.delete Gem.configuration.credentials_path if File.exist?(Gem.configuration.credentials_path)
  end

  def test_execute_when_user_is_signed_in
    FileUtils.mkdir_p File.dirname Gem.configuration.credentials_path
    FileUtils::touch Gem.configuration.credentials_path

    assert_output(%r{You have successfully signed out}) {@cmd.execute }
    assert_equal File.exist?(Gem.configuration.credentials_path), false
  end

  def test_execute_when_not_signed_in # i.e. no credential file created
    assert_output(%r{You are not currently signed in}) {@cmd.execute }
  end

end
