# Debugging

Debugging Bundler can be challenging, don't be discouraged 🤗.

Make sure you've followed the [development setup](SETUP.md) docs before trying to debug.

## Debugging in tests

Your best option is to print debug in the test suite. Put `puts` statements anywhere you want to see an object or variable and you'll see your `puts` in the console output.

```ruby
puts "@defintion: #{@defintion}"
puts "specification.class.name: #{specification.class.name}"
puts "spec.method(:to_checksum).source_location: #{spec.method(:to_checksum).source_location}"
# etc
```

Most tests use Open3 to run Bundler in a sub process and capture the output into a string, which makes it impossible to use pry even if you can get it to load.

## Interactive debugging locally

When testing Bundler locally, you can use pry for interactive debugging.

The easiest way to test locally is to set up a directory with a Gemfile and run your Bundler shell alias (see the [development setup](SETUP.md) docs for instructions on setting up the alias).

We recommend putting this directory inside of `tmp` so that your local tests don't accidentally get committed.

```bash
cd tmp
mkdir [name of directory for local testing] && cd [name of directory for local testing]
dbundle init
```

And then you should have a Gemfile ready for you to edit as needed for your testing.

### RubyGems test case
By default, the initialized Gemfile's remote is `"https://rubygems.org"`. You can add any gem hosted on rubygems and then run your Bundler shell alias (`dbundle`) to test your code.

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gem 'tiny_css'
```

Put a `binding.pry` anywhere you want the debugger to break. Run your Bundler shell alias.

```bash
RUBYOPT=-rpry dbundle
```

And your breakpoint will display, paused, in your console.

### Gem from local remote
If you have a very specific scenario you want to test (maybe an example that failed while running the test suite), the easiest way is to use the tmp gems from a previous test suite run.

Run the test suite in parallel if you haven't already.

```bash
bin/parallel_rspec
```

Then you'll find built gems in the `bundler/tmp` directory, e.g. `bundler/tmp/1/gems/remote1/`

You can set up your Gemfile 

```ruby
# frozen_string_literal: true

source "file:///[path to repo's bundler directory]/tmp/1/gems/remote1/"

gem "rack", '=0.9.1'
```

And then you can test in the same way as you did in the previous example when fetching the gem from the RubyGems source.