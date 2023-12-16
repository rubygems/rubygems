# frozen_string_literal: true

RSpec.describe Bundler::UI::JsonShell do
  subject { described_class.new }

  before { subject.level = "debug" }

  describe "#info" do
    before { subject.level = "info" }
    it "prints to stderr" do
      expect { subject.info("info") }.to output("info\n").to_stderr
    end
  end

  describe "#confirm" do
    before { subject.level = "confirm" }
    it "prints to stderr" do
      expect { subject.confirm("confirm") }.to output("confirm\n").to_stderr
    end
  end

  describe "#warn" do
    before { subject.level = "warn" }
    it "prints to stderr" do
      expect { subject.warn("warning") }.to output("warning\n").to_stderr
    end
  end

  describe "#debug" do
    it "prints to stderr" do
      expect { subject.debug("debug") }.to output("debug\n").to_stderr
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
        { foo: "Entry 1", bar: 5, baz: "a few words" },
        { foo: :two, bar: [3, 4, 5], baz: "less", extra_key: "extra data" },
        { foo: 3, baz: "not as long" },
      ]
    end

    it "constructs and prints the table to stdout properly" do
      # * includes a nil-values entry for the missing :bar
      # * includes the non-header-ed :extra_key key
      expanded_json =
        <<~JSON
          [
          {"foo":"Entry 1","bar":5,"baz":"a few words"},
          {"foo":"two","bar":[3,4,5],"baz":"less","extra_key":"extra data"},
          {"foo":3,"bar":null,"baz":"not as long"}
          ]
        JSON
      expected_json = expanded_json.split("\n").join + "\n"
      expect { subject.table(header, records) }.to output(expected_json).to_stdout
    end

    context "with :pretty => true" do
      it "constructs and prints the table to stdout properly" do
        # * includes a nil-values entry for the missing :bar
        # * includes the non-header-ed :extra_key key
        expected_json = <<~JSON
          [
            {
              "foo": "Entry 1",
              "bar": 5,
              "baz": "a few words"
            },
            {
              "foo": "two",
              "bar": [
                3,
                4,
                5
              ],
              "baz": "less",
              "extra_key": "extra data"
            },
            {
              "foo": 3,
              "bar": null,
              "baz": "not as long"
            }
          ]
        JSON
        expect { subject.table(header, records, pretty: true) }.to output(expected_json).to_stdout
      end
    end
  end
end
