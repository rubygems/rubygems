# Documentation

Code needs explanation, and sometimes those who know the code well have trouble explaining it to someone just getting into it. We welcome documentation suggestions and patches from everyone, especially from those new to RubyGems or Bundler.

## Where to contribute

Documentation for RubyGems and Bundler is managed in two places:

- **Guides and tutorials**: [RubyGems Guides](https://guides.rubygems.org/) — hosted in the [rubygems/guides](https://github.com/rubygems/guides) repository
- **Bundler CLI man pages**: Built from `.ronn` files in `lib/bundler/man/` in this repository and published as the [Bundler command reference](https://guides.rubygems.org/command-reference/bundle/) on RubyGems Guides

All documentation other than Bundler command man pages — including guides, tutorials, and reference material for both RubyGems and Bundler — should be contributed to the [rubygems/guides](https://github.com/rubygems/guides) repository.

## Documentation Vision and Goals

Our goal is to provide three types of documentation:

* High-level overviews that provide topical guidance
* Step-by-step tutorials
* Command-specific reference material for the CLI

Topics include:

- Gem creation, packaging, and publishing
- Dependency management best practices
- Version constraints and semantic versioning
- Security and trust
- Installing and using Bundler
- Managing application dependencies with Bundler

Additionally, this documentation should be readily available in a logical place and easy to follow.

Someday, we'd like to create deep-dive reference material about the inner workings of Bundler. However, while this is part of our overall vision, it is not the focus of our current work.

## Writing guides and tutorials

To contribute to [RubyGems Guides](https://guides.rubygems.org/):

1. Fork and clone the [rubygems/guides](https://github.com/rubygems/guides) repository
2. Add or edit a Markdown file in the root directory
3. Include the required frontmatter:
   ```
   ---
   layout: default
   title: Your Guide Title Here
   url: /your_guide_url
   previous: /previous_guide
   next: /next_guide
   ---
   ```
4. Submit a pull request with your changes

See the [rubygems/guides README](https://github.com/rubygems/guides#readme) for setup and preview instructions.

## Writing Bundler man pages

Man pages are the output printed when you run `bundle help` (or `bundler help`). These pages can be a little tricky to format and preview, but are pretty straightforward once you get the hang of it.

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

The [Bundler command reference](https://guides.rubygems.org/command-reference/bundle/) on RubyGems Guides is generated from these `.ronn` files by the `bundler_reference` task in the [rubygems/guides](https://github.com/rubygems/guides) repository, and republished when RubyGems is released.

### Testing

We have tests for our documentation! The most important test file to run before you make your pull request is the one for the `help` command and another for documentation quality.

```
$ bin/rspec spec/commands/help_spec.rb
$ bin/rake quality:check
```
