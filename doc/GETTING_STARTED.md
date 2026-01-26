# Getting Started

## Prerequisites and Setup

[Fork the ruby/rubygems repo](https://github.com/ruby/rubygems) and clone the fork onto your machine. ([Follow this tutorial](https://help.github.com/articles/fork-a-repo/) for instructions on forking a repo.)

Install development dependencies from the repository root directory:

    bin/rake setup

> **NOTE**: If the above fails with permission related errors, you're most
> likely using a global Ruby installation (like the one packaged by your OS),
> which sets `GEM_HOME` to a location regular users can't write to. Consider
> using a Ruby version manager like [RVM](https://github.com/rvm/rvm),
> [rbenv](https://github.com/rbenv/rbenv),
> [chruby](https://github.com/postmodern/chruby) or [asdf](https://github.com/asdf-vm/asdf-ruby). These will install Ruby to a
> location regular users can write to, so you won't run into permission issues.
> Alternatively, consider setting `GEM_HOME` environment variable to a writable
> location with something like `export GEM_HOME=/tmp/rubygems.gems` and try
> again.

## Testing Your Local Changes

### RubyGems Commands

To run RubyGems commands like `gem install` from your local copy:

    ruby -Ilib exe/gem install

### Bundler Commands

To run Bundler commands like `bundle install` from your local copy:

    bundler/bin/bundle install

## Running Tests

### RubyGems Tests

To run the entire RubyGems test suite:

    bin/rake test

To run an individual test file, for example `test/rubygems/test_deprecate.rb`:

    ruby -Ilib:test:bundler/lib test/rubygems/test_deprecate.rb

To run a specific test method named `test_default`:

    ruby -Ilib:test:bundler/lib test/rubygems/test_deprecate.rb -n /test_default/

### Bundler Tests

To run the entire Bundler test suite in parallel from the `bundler/` directory:

    bin/parallel_rspec

For realworld higher level specs (also run in CI):

    bin/rake spec:realworld

To run an individual Bundler test file, for example `spec/install/gems/standalone_spec.rb`, from the `bundler/` directory:

    bin/rspec spec/install/gems/standalone_spec.rb

## Developing Bundler and RubyGems Together

When developing Bundler features or bug fixes that require changes in RubyGems, you can set the `RGV` environment variable to point to the repository root so Bundler's test suite picks up those changes:

    RGV=.. bin/parallel_rspec

You can also test against specific RubyGems versions:

    RGV=v3.2.33 bin/parallel_rspec

It's recommended to set this variable permanently using [direnv](https://direnv.net) for consistent development.

## Code Style and Quality

Check code style compliance:

    bin/rake rubocop

Optionally configure git hooks to check this before every commit:

    bin/rake git_hooks

## Shell Aliases (Optional)

Set up a shell alias to run Bundler from your clone for convenience.

### Bash

Add this to your `~/.bashrc` or `~/.bash_profile`:

    alias dbundle='ruby /[repo root]/bundler/bin/bundle'

See [this tutorial](https://www.moncefbelyamani.com/create-aliases-in-bash-profile-to-assign-shortcuts-for-common-terminal-commands/) for adding aliases to your `~/.bashrc` profile.

### Windows (PowerShell)

Add this to your [PowerShell profile](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.4) (use `vim $profile` on the command line if you have `vim` installed):

```powershell
$Env:RUBYOPT="-rdebug"
function dbundle
{
	& "ruby.exe" E:\[repo root]\bundler\bin\bundle $args
}
```

For a better command line experience on Windows, consider using [Windows Terminal](https://github.com/microsoft/terminal).

## Git Commits

Please sign your commits. Although not required to contribute, it ensures that code you submit wasn't altered during transfer and proves it came from you.

See [Git commit signing documentation](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work) or [GitHub's guide](https://help.github.com/en/articles/signing-commits) for details on generating signatures and automatically signing your commits.

### Debugging

See [DEBUGGING.md](DEBUGGING.md) for debugging tips and techniques.
