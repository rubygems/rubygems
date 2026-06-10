# frozen_string_literal: true

require "bundler/cli"
require "stringio"

RSpec.describe Bundler::CLI::Common do
  describe "gem_not_found_message" do
    it "should suggest alternate gem names" do
      message = subject.gem_not_found_message("ralis", ["BOGUS"])
      expect(message).to match("Could not find gem 'ralis'.$")
      message = subject.gem_not_found_message("ralis", ["rails"])
      expect(message).to match("Did you mean 'rails'?")
      message = subject.gem_not_found_message("Rails", ["rails"])
      expect(message).to match("Did you mean 'rails'?")
      message = subject.gem_not_found_message("meail", %w[email fail eval])
      expect(message).to match("Did you mean 'email'?")
      message = subject.gem_not_found_message("nokogri", %w[nokogiri rails sidekiq dog])
      expect(message).to match("Did you mean 'nokogiri'?")
      message = subject.gem_not_found_message("methosd", %w[method methods bogus])
      expect(message).to match(/Did you mean 'method(|s)' or 'method(|s)'?/)
    end
  end

  describe "ask_for_number" do
    BACKSPACE = 127.chr # DEL
    CTRL_C = 3.chr      # ETX
    CTRL_D = 4.chr      # EOT

    # Run ask_for_number against a scripted sequence of keypresses, with the
    # single-keypress path forced on and $stdin/$stdout swapped for fakes.
    def select(keys, max)
      allow(described_class).to receive(:single_keypress_supported?).and_return(true)
      input = double("stdin")
      allow(input).to receive(:getch).and_return(*keys)

      old_stdin = $stdin
      old_stdout = $stdout
      $stdin = input
      $stdout = StringIO.new
      described_class.ask_for_number(max)
    ensure
      $stdin = old_stdin
      $stdout = old_stdout
    end

    context "when no option number is a prefix of another (fewer than ten options)" do
      it "accepts a choice on a single keypress, without Enter" do
        expect(select(["1"], 3)).to eq(1)
        expect(select(["3"], 3)).to eq(3)
      end

      it "treats 0 as the exit choice" do
        expect(select(["0"], 3)).to eq(0)
      end

      it "ignores a digit that cannot match any option" do
        expect(select(["8", "2"], 3)).to eq(2)
      end
    end

    context "when an option number is a prefix of another (ten or more options)" do
      it "waits for a second digit before resolving an ambiguous prefix" do
        expect(select(["1", "0"], 11)).to eq(10)
        expect(select(["1", "1"], 11)).to eq(11)
      end

      it "still accepts an unambiguous digit immediately" do
        expect(select(["7"], 11)).to eq(7)
        expect(select(["0"], 11)).to eq(0)
      end

      it "resolves the shorter number when Enter is pressed" do
        expect(select(["1", "\r"], 11)).to eq(1)
        expect(select(["1", "\n"], 11)).to eq(1)
      end
    end

    it "supports backspace to edit the buffer" do
      expect(select(["1", BACKSPACE, "3"], 11)).to eq(3)
    end

    it "aborts with the conventional SIGINT status (130) on Ctrl-C" do
      expect { select([CTRL_C], 3) }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(130)
      end
    end

    it "returns nil at EOF instead of looping" do
      expect(select([nil], 3)).to be_nil
    end

    it "cancels (returns nil) on Ctrl-D" do
      expect(select([CTRL_D], 3)).to be_nil
    end

    it "falls back to a line prompt when single keypress input is unsupported" do
      allow(described_class).to receive(:single_keypress_supported?).and_return(false)
      allow(Bundler.ui).to receive(:ask).with("> ").and_return("2")
      expect(described_class.ask_for_number(3)).to eq(2)
    end
  end
end
