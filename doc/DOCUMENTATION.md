# Documentation

Code needs explanation, and sometimes those who know the code well have trouble explaining it to someone just getting into it. We welcome documentation suggestions and patches from everyone, especially from those new to RubyGems or Bundler.

This repository contains documentation for both RubyGems and Bundler. We have multiple documentation sources depending on what you're documenting:

## RubyGems Documentation

**RubyGems guides**: https://guides.rubygems.org/

For RubyGems documentation contributions:
- Submit issues or pull requests to the [RubyGems Guides repository](https://github.com/rubygems/guides)
- This covers topics like gem creation, publishing, versioning, and best practices

## Bundler Documentation

**Bundler help & man pages**: Built into the `bundler/` directory

**Bundler documentation site**: https://bundler.io

For Bundler documentation contributions:
- **Command documentation** (ex: `bundle clean`): Contribute to man pages in this repository (`bundler/lib/bundler/man/`)
- **Guides and tutorials** (ex: "Using Bundler with Rails"): Open an issue or pull request in the [bundler-site](https://github.com/rubygems/bundler-site) repository
- **Using Bundler with gems**: Additional documentation on [RubyGems guides](https://guides.rubygems.org/)

## Documentation Vision and Goals

### RubyGems

RubyGems documentation focuses on:
- Gem creation, packaging, and publishing
- Dependency management best practices
- Version constraints and semantic versioning
- Security and trust topics

Goals are to provide guides and tutorials at https://guides.rubygems.org/ that help users understand and effectively use RubyGems.

### Bundler

Bundler documentation is split across multiple places:

1. Built-in `help` (including usage information and man pages)
2. [Bundler documentation site](https://bundler.io)
3. [RubyGems guides](https://guides.rubygems.org/) (for gem publishing topics)

Bundler documentation should provide users with assistance:

1. Installing Bundler
2. Using Bundler to manage an application's dependencies
3. Using Bundler to create, package, and publish gems

Our goal is to provide three types of documentation:

* High-level overviews that provide topical guidance
* Step-by-step tutorials
* Command-specific reference material for the CLI

Additionally, this documentation should be readily available in a logical place and easy to follow.

Someday, we'd like to create deep-dive reference material about the inner workings of Bundler. However, while this is part of our overall vision, it is not the focus of our current work.

## Writing RubyGems Documentation

### Contributing to RubyGems guides

To contribute to RubyGems documentation:

1. Fork and clone the [rubygems/guides](https://github.com/rubygems/guides) repository
2. Add or edit Markdown files in the `_pages/` directory
3. Follow the existing format and style guidelines
4. Submit a pull request with your changes

See the [RubyGems Guides repository](https://github.com/rubygems/guides) for detailed contribution instructions.

## Writing Bundler Documentation

### Writing docs for man pages

*Any commands or file paths in this document assume that you are inside [the bundler/ directory of the ruby/rubygems repository](https://github.com/ruby/rubygems/tree/master/bundler).*

A primary source of help for Bundler users are the man pages: the output printed when you run `bundle help` (or `bundler help`). These pages can be a little tricky to format and preview, but are pretty straightforward once you get the hang of it.

_Note: `bundler` and `bundle` may be used interchangeably in the CLI. This guide uses `bundle` because it's cuter._

### What goes in man pages?

We use man pages for Bundler commands used in the CLI (command line interface). They can vary in length from large (see `bundle install`) to very short (see `bundle clean`).

To see a list of commands available in the Bundler CLI, type:

      $ bundle help

Our goal is to have a man page for every command.

Don't see a man page for a command? Make a new page and send us a PR! We also welcome edits to existing pages.

### Creating a new man page

To create a new man page, simply create a new `.ronn` file in the `lib/bundler/man/` directory.

For example: to create a man page for the command `bundle cookies` (not a real command, sadly), I would create a file `lib/bundler/man/bundle-cookies.1.ronn` and add my documentation there.

### Formatting

Our man pages use ronn formatting, a combination of Markdown and standard man page conventions. It can be a little weird getting used to it at first, especially if you've used Markdown a lot.

[The ronn guide formatting guide](https://rtomayko.github.io/ronn/ronn.7.html) provides a good overview of the common types of formatting.

In general, make your page look like the other pages: utilize sections like `##OPTIONS` and formatting like code blocks and definition lists where appropriate.

If you're not sure if the formatting looks right, that's ok! Make a pull request with what you've got and we'll take a peek.

### Previewing

To preview your changes as they will print out for Bundler users, you'll need to run a series of commands:

```
$ bin/rake dev:deps
$ bin/rake man:build
$ man ./lib/bundler/man/bundle-cookies.1
```

If you make more changes to `bundle-cookies.1.ronn`, you'll need to run the `bin/rake man:build` again before previewing.

### Testing

We have tests for our documentation! The most important test file to run before you make your pull request is the one for the `help` command and another for documentation quality.

```
$ bin/rspec ./spec/commands/help_spec.rb
$ bin/rspec ./spec/quality_spec.rb
```

## Writing docs for [the Bundler documentation site](https://bundler.io)

### Primary commands and utilities

If you'd like to submit a pull request for any of the primary commands or utilities on [the Bundler documentation site](https://bundler.io), please follow the instructions above for writing documentation for man pages from the `ruby/rubygems` repository. They are the same in each case.

**Note**: Editing `.ronn` files from the `ruby/rubygems` repository for the primary commands and utilities documentation is all you need 🎉. There is no need to manually change anything in the `rubygems/bundler-site` repository, because the man pages and the docs for primary commands and utilities on [the Bundler documentation site](https://bundler.io) are one in the same. They are generated automatically from the `ruby/rubygems` repository's `.ronn` files when you run `bin/rake man:build`.

### Guides and tutorials

To add a guide or tutorial to the [Bundler documentation site](https://bundler.io):

1. Go to the [bundler-site](https://github.com/rubygems/bundler-site) repository
2. Navigate to `/bundler-site/source/current_version_of_bundler/guides`
3. Add a new [Markdown file](https://guides.github.com/features/mastering-markdown/) (ending in `.md`)
4. Format the title correctly:
   ```
   ---
   title: Your Guide Title Here
   ---
   ```
5. Submit a pull request with your changes
