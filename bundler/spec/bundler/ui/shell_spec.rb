# frozen_string_literal: true

RSpec.describe Bundler::UI::Shell do
  subject { described_class.new }

  before { subject.level = "debug" }

  describe "#info" do
    before { subject.level = "info" }
    it "prints to stdout" do
      expect { subject.info("info") }.to output("info\n").to_stdout
    end
  end

  describe "#confirm" do
    before { subject.level = "confirm" }
    it "prints to stdout" do
      expect { subject.confirm("confirm") }.to output("confirm\n").to_stdout
    end
  end

  describe "#warn" do
    before { subject.level = "warn" }
    it "prints to stderr" do
      expect { subject.warn("warning") }.to output("warning\n").to_stderr
    end
  end

  describe "#debug" do
    it "prints to stdout" do
      expect { subject.debug("debug") }.to output("debug\n").to_stdout
    end
  end

  describe "#error" do
    before { subject.level = "error" }

    it "prints to stderr" do
      expect { subject.error("error!!!") }.to output("error!!!\n").to_stderr
    end

    context "when stderr is closed" do
      it "doesn't report anything" do
        output = begin
                   result = StringIO.new
                   result.close

                   $stderr = result

                   subject.error("Something went wrong")

                   result.string
                 ensure
                   $stderr = STDERR
                 end
        expect(output).to_not eq("Something went wrong")
      end
    end
  end

  describe "#table" do
    before { subject.level = "info" }
    let(:header) { { foo: "Foo", bar: "Bar (but longer)", baz: "Baz" } }
    let(:records) do
      [
        { foo: "Entry 1", bar: 5, baz: ["a", "few", :words] },
        { foo: :two, bar: [1, 2, 3], baz: "less", extra_key: "extra data" },
        { foo: 3, baz: "not as long" },
      ]
    end

    it "constructs and prints the table to stdout properly" do
      # * Skips the extra data (doesn't match anything in the header)
      # * Handles the missing entry
      # * Converts the non-strings (collapsing/stringifying the arrays)
      # * ignores the extra_key
      expected_table = <<~TABLE
        Foo      Bar (but longer)  Baz
        Entry 1  5                 a, few, words
        two      1, 2, 3           less
        3                          not as long
      TABLE
      expect { subject.table(header, records) }.to output(expected_table).to_stdout
    end
  end
end
