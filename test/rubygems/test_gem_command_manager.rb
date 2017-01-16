# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/command_manager'

class TestGemCommandManager < Gem::TestCase

  def setup
    super

    @command_manager = Gem::CommandManager.new
  end

  def test_find_command
    command = @command_manager.find_command 'install'

    assert_kind_of Gem::Commands::InstallCommand, command

    command = @command_manager.find_command 'ins'

    assert_kind_of Gem::Commands::InstallCommand, command
  end

  def test_find_command_ambiguous
    e = assert_raises Gem::CommandLineError do
      @command_manager.find_command 'u'
    end

    assert_equal 'Ambiguous command u matches [uninstall, unpack, update]',
                 e.message
  end

  def test_find_command_ambiguous_exact
    ins_command = Class.new
    Gem::Commands.send :const_set, :InsCommand, ins_command

    @command_manager.register_command :ins

    command = @command_manager.find_command 'ins'

    assert_kind_of ins_command, command
  ensure
    Gem::Commands.send :remove_const, :InsCommand
  end

  def test_find_command_unknown
    e = assert_raises Gem::CommandLineError do
      @command_manager.find_command 'xyz'
    end

    assert_equal 'Unknown command xyz', e.message
  end

  def test_run_interrupt
    old_load_path = $:.dup
    $: << File.expand_path("test/rubygems", @@project_dir)
    Gem.load_env_plugins

    @command_manager.register_command :interrupt

    use_ui @ui do
      assert_raises Gem::MockGemUi::TermError do
        @command_manager.run %w[interrupt]
      end
      assert_equal '', ui.output
      assert_equal "ERROR:  Interrupted\n", ui.error
    end
  ensure
    $:.replace old_load_path
    Gem::CommandManager.reset
  end

  def test_run_crash_command
    old_load_path = $:.dup
    $: << File.expand_path("test/rubygems", @@project_dir)

    @command_manager.register_command :crash
    use_ui @ui do
      assert_raises Gem::MockGemUi::TermError do
        @command_manager.run %w[crash]
      end
      assert_equal '', ui.output
      err = ui.error.split("\n").first
      assert_equal "ERROR:  Loading command: crash (RuntimeError)", err
    end
  ensure
    $:.replace old_load_path
    @command_manager.unregister_command :crash
  end

  def test_process_args_bad_arg
    use_ui @ui do
      assert_raises Gem::MockGemUi::TermError do
        @command_manager.process_args %w[--bad-arg]
      end
    end

    assert_match(/invalid option: --bad-arg/i, @ui.error)
  end
end
