# Bundler Development setup

To work on Bundler, you'll probably want to do a couple of things:

* [Fork the Rubygems repo](https://github.com/rubygems/rubygems), and clone the fork onto your machine. ([Follow this tutorial](https://help.github.com/articles/fork-a-repo/) for instructions on forking a repo.)

* Install `graphviz` package using your package manager:

        $ sudo apt-get install graphviz -y

    And for OS X (with brew installed):

        $ brew install graphviz

* Install development dependencies from the rubygems root directory:

        $ rake setup

* Change into the bundler directory:

        $ cd bundler

* Install Bundler's test dependencies:

        $ bin/rake spec:parallel_deps

* Now you can run the test suite in parallel:

        $ bin/parallel_rspec

* Set up a shell alias to run Bundler from your clone, e.g. a Bash alias ([follow these instructions](https://www.moncefbelyamani.com/create-aliases-in-bash-profile-to-assign-shortcuts-for-common-terminal-commands/) for adding aliases to your `~/.bashrc` profile):

        $ alias dbundle='ruby /path/to/bundler/repo/spec/support/bundle.rb'

## Jointly developing on Bundler and RubyGems

When developing Bundler features or bug fixes that require changes in RubyGems,
you can make sure Bundler's test suite picks up those changes by setting the
`RGV` environment variable to point to the root of the repository, like this:

```
RGV=.. bin/parallel_rspec
```

It's a good idea to make sure that your changes always work against the latest
RubyGems, so setting this variable permanently might be a good idea. You can use
[direnv](https://direnv.net) for that.

The `RGV` environment variable can also be set to arbitrary RubyGems versions,
to make sure your changes in Bundler work fine with those versions. For example,

```
RGV=v3.2.33 bin/parallel_rspec
```

## Debugging with `pry`

To dive into the code with Pry: `RUBYOPT=-rpry dbundle` to require pry and then run commands.

For background context: you can manipulate environment variables in Ruby to control the Ruby interpreter's behavior. Ruby uses the `RUBYOPT` environment variable to specify options to launch Ruby with.

The arguments of `RUBYOPT` are applied as if you had typed them as flags after `ruby`. The `-r` flag means 'require'. So saying `-rpry` means `require 'pry'`. To illustrate, `ruby -rpry /path/to/bundle` is the same as `RUBYOPT=-rpry ruby /path/to/bundle`.

So, `RUBYOPT=-rpry dbundle` is saying "require pry and require this path to Bundler", which means that you will start your development environment with `pry` and your local bundler.

_Why is this necessary?_ Why isn't `require 'pry'; binding.pry` enough?

The reason for combining `RUBYOPT` with `dbundle` is because Bundler takes over what gems are available. If you have `pry` installed on your machine but not included in the Gemfile, Bundler itself will remove `pry` from the list of gems you can require. Setting `RUBYOPT=-rpry` is a way to require `pry` before Bundler takes over and removes it from the list of gems that can be required. That way, later, you can take advantage of `binding.pry` and have it work.
Unfortunately, if you waited until the point of `binding.pry` to `require 'pry'`, it would fail anytime `pry` is not in the Gemfile.
