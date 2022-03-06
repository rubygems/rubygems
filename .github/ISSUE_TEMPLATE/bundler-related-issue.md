---
name: Bundler related issue
about: This template is intended for Bundler specific related issues.
title: ''
labels: 'Bundler'
assignees: ''

---

<!--

Thank you for contributing to the [rubygems](https://github.com/rubygems/rubygems) repository, and specifically to the [Bundler](https://bundler.io/) gem.

Sometimes you can find a solution to your issue by reading some documentation.

* Instructions for common Bundler uses can be found on the [Bundler documentation site](https://bundler.io/).
* Detailed information about each Bundler command, including help with common problems, can be found in the [Bundler man pages](https://bundler.io/man/bundle.1.html) or [Bundler Command Line Reference](https://bundler.io/commands.html).
* We also have a document detailing solutions to common problems: https://github.com/rubygems/rubygems/blob/master/bundler/doc/TROUBLESHOOTING.md.

If you're still stuck, please fill in the following sections so we can process your issue as fast as possible:

-->

### Describe the problem as clearly as you can

<!-- Replace this with an explanation of the problem you are having. Be as much clear and precise as you can. -->

### Did you try upgrading rubygems & bundler?

<!--

Make sure you're using the latest version of both `bundler` and `rubygems`.

Running `gem update --system` should get both installed on your system, and then
`bundle update --bundler` should change your lockfile to use the new version of
bundler that was just installed.

It's likely that your issue has been fixed in recent versions, so just upgrading
might do the trick, and will also save us some time :)

-->

### Post steps to reproduce the problem

<!--

Fill this with a list of steps maintainers can follow to reproduce your issue. Note that while you are seeing this issue in your computer, maintainers might not see the same thing on theirs. There is a number of things that could influence this:

* How your ruby is setup (OS package, from source, using a version manager).
* How bundler & rubygems are configured.
* The version of each involved piece of software that you are using.
* ...

The more complete the steps to simulate your particular environment are, the easier it will be for maintainers to reproduce your issue on their machines.

Ideally, we recommend you to set up the list of steps as a [Dockerfile](https://docs.docker.com/get-started/). A Dockerfile provides a neutral environment that should give the same results, no matter where it's run.

-->

### Which command did you run?

<!-- Replace this with the specific command that is causing trouble. -->

### What were you expecting to happen?

<!-- Replace this with the results you expected before running the command. -->

### What actually happened?

<!-- Replace this with the actual result you got. Paste the output of your command here. -->

### If not included with the output of your command, run `bundle env` and paste the output below

<!-- Replace this with the result of `bundle env`. Don't forget to anonymize any private data! -->
