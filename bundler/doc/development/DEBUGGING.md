# Debugging

Debugging Bundler can be challenging, don't be discouraged 🤗.

Make sure you've followed the [development setup](SETUP.md) docs before trying to debug.

## Print debugging

The easiest way to debug is to print debug. Put `puts` statements anywhere in the code that you want to see an object or variable and you'll see your `puts` in the console output.

This can be especially helpful when running tests.

```ruby
puts "stacktrace: #{caller_locations(0).join("\n")}"
puts "@definition: #{@definition}"
puts "specification.class.name: #{specification.class.name}"
puts "spec.method(:to_checksum).source_location: #{spec.method(:to_checksum).source_location}"
# etc
```

To learn more print debugging strategies, [TODO: link to doc]

## REPL debugging

REPL (or Read-Eval-Print Loop) is a way to interact with your code.

With REPL you can look at the values of objects and variables, the stack trace, where methods are defined etc.

To use REPL, place a `binding.irb` wherever you'd like to take a look around. An interactive `irb` console will open when your code gets to your breakpoint.

To learn more about using IRB, [TODO: link to doc]

## Interactive debugging

Interactive debugging is like REPL + the ability to advance the code execution line by line.

When testing Bundler locally, you can use any debugger that you are comfortable with for interactive debugging.

[`debug`](https://github.com/ruby/debug) and [`pry-byebug`](https://github.com/deivid-rodriguez/pry-byebug) are common favorites. `debug` has been included with Ruby since v3.1.

You just need your chosen debugger gem installed globally. Then you will need to require it on the command line before running your local Bundler.

```bash
RUBYOPT=-rdebug dbundle # for the debug gem
RUBYOPT=-rpry-byebug dbundle # for pry-byebug
```

> **Note**
> Interactive debugging is not possible in the test suite. Most tests use Open3 to run Bundler in a sub process and capture the output into a string, which makes it impossible to use pry even if you can get it to load.

### Local setup

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

Put a breakpoint anywhere you want the debugger to pause (`binding.break` for `debug` or `binding.pry` for `pry-byebug`). Run your Bundler shell alias.

```bash
RUBYOPT=-rdebug dbundle
```

And your breakpoint will display, paused, in your console.

### Gem from local remote
If you have a very specific scenario you want to test (maybe an example that failed while running the test suite), the easiest way is to use the tmp gems from a previous test suite run.

Run the test suite in parallel if you haven't already.

```bash
bin/parallel_rspec
```

Then you'll find built gems in the `bundler/tmp` directory, e.g. `bundler/tmp/1/gems/remote1/`

You can set up your Gemfile with a file source pointing to the built gems from your test run.

```ruby
# frozen_string_literal: true

source "file:///[path to repo's bundler directory]/tmp/1/gems/remote1/"

gem "rack", '=0.9.1'
```

Then you can test in the same way as you did in the previous example when fetching the gem from the RubyGems source.