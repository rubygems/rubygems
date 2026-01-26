# How to Contribute

Thank you for your interest in contributing to RubyGems and Bundler! Community involvement is essential to both RubyGems and Bundler. We welcome contributions from everyone, and we want to keep it as easy as possible to contribute changes.

## Code of Conduct

By participating in this project, you agree to abide by the terms of the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

Before submitting a contribution:

1. **Set up your development environment** - See [GETTING_STARTED.md](doc/GETTING_STARTED.md) for detailed setup instructions
2. **Understand the repository structure** - This is a monorepo containing both RubyGems and Bundler:
   - RubyGems code is in the root `lib/` and `exe/` directories
   - Bundler code is in the `bundler/` subdirectory

## Contribution Guidelines

All contributions to this repository should follow these guidelines:

1. **Write tests** - New features must be coupled with tests. Bug fixes should include a test that reproduces the issue.

2. **Code style compliance**:
   - No trailing whitespace
   - Use two-space indentation
   - Run `bin/rake rubocop` to check style compliance

3. **File management** (RubyGems only):
   - If you add or remove files in the RubyGems portion of the repo, update `Manifest.txt` by running `bin/rake update_manifest`

4. **Preserve version history**:
   - Don't modify version numbers or changelog files directly; maintainers handle these

5. **Ask questions** - Have questions? Feel free to [open an issue](https://github.com/ruby/rubygems/issues)

For more information on contributing to the RubyGems ecosystem, see [guides.rubygems.org/contributing](https://guides.rubygems.org/contributing/).

## First-Time Contributors

We track [good first issues](https://github.com/ruby/rubygems/issues?q=is%3Aissue+is%3Aopen+label%3Abundler+label%3A%22good+first+issue%22) to help new contributors get started. Here are some great ways to begin:

- **Test prerelease versions**: Run `gem install bundler --pre` and report any issues
- **Report bugs or suggest features**: [Open an issue](https://github.com/ruby/rubygems/issues/new?labels=Bundler&template=bundler-related-issue.md) (see [new features documentation](doc/NEW_FEATURES.md))
- **Improve documentation**: Contribute to the [Bundler website](https://bundler.io) or [man pages](https://bundler.io/man/bundle.1.html)
- **Triage issues**: [Check issue completeness](doc/ISSUE_TRIAGE.md) and help close incomplete reports
- **Write tests**: Add failing tests for [reported bugs](https://github.com/ruby/rubygems/issues) or backfill missing test coverage
- **Review pull requests**: Provide feedback on [pull requests](https://github.com/ruby/rubygems/pulls)
- **Improve code**: No patch is too small—fix typos, improve code clarity, or clean up whitespace
- **Contribute features**: See [adding new features](doc/NEW_FEATURES.md)

## Pull Request Guidelines

See [doc/PULL_REQUESTS.md](doc/PULL_REQUESTS.md) for detailed guidelines.

## Community and Support

Community involvement is vital to both projects:

- **Answer questions**: Help others on the [issue tracker](https://github.com/ruby/rubygems/issues) or [Stack Overflow](https://stackoverflow.com/questions/tagged/bundler) (questions about RubyGems, Bundler, and Ruby in general are welcome)
- **Share knowledge**: Write blog posts, create examples, make videos, or share your experiences
- **Improve documentation**: Suggest improvements to [bundler.io](https://bundler.io) via issues or pull requests on the [bundler-site](https://github.com/rubygems/bundler-site) repository

## Supporting the Projects

Both RubyGems and Bundler are managed by [Ruby Central](https://rubycentral.org), a non-profit organization supporting the Ruby community through projects like these, as well as [RubyConf](https://rubyconf.org) and [RubyGems.org](https://rubygems.org).

You can support Ruby Central by:

- Attending or [sponsoring](mailto:sponsors@rubycentral.org) a conference
- [Joining as a supporting member](https://rubycentral.org/#/portal/signup)
