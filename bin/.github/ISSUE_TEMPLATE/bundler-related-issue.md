---
name: Bundler related issue
about: This template is intended for Bundler specific related issues.
title: ''
labels: 'Bundler'
assignees: ''

---

<!--

Thank you for contributing to the rubygems) repository, and specifically to the Bundler gem.

Please fill in the following sections so we can process your issue as fast as possible

-->

### Describe the problem as clearly as you can

<!-- Replace this with an explanation of your problem. Be as clear and precise as you can. -->

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

Fill this with a list of steps maintainers can follow to reproduce your issue. Note that while you see this issue in your computer, maintainers might not see the same thing on theirs. There are many things that could influence this:

* How your ruby is setup (OS package, from source, using a version manager).
* How bundler & rubygems are configured.
* The version of each involved piece of software that you are using.
* ...

The more complete the steps to simulate your particular environment are, the easier it will be for maintainers to reproduce your issue on their machines.

Ideally, we recommend you set up the list of steps as a Dockerfile. A Dockerfile provides a neutral environment that should give the same results, no matter where it's run.

-->

### Which command did you run?

<!-- Replace this with the specific command that is causing trouble. -->

### What were you expecting to happen?

<!-- Replace this with the results you expected before running the command. -->

### What actually happened?

<!-- Replace this with the actual result you got. Paste the output of your command here. -->

### If not included with the output of your command, run `bundle env` and paste the output below

<!-- Replace this with the result of `bundle env`. Don't forget to anonymize any private data! -->
