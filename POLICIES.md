## Pull Requests

Contributions to RubyGems are made via GitHub pull requests, which must be
approved by a project committer other than the author. To approve a PR, a
maintainer can leave a comment including the text "@bundlerbot r+", indicating
that they have reviewed the PR and approve it. Bundlerbot will then
automatically create a merge commit, test the merge, and land the PR if the
merge commit passes the tests.

This process guarantees that our release branches always have passing tests,
and reduces siloing of information to a single contributor. For a full list of
possible commands, see [the Bundlerbot
documentation](https://bors.tech/documentation/).

## Long-Term Support

RubyGems will support Ruby versions for as long as the Ruby team supports that
Ruby version. That means that the latest RubyGems release will always support
the currently-supported Ruby versions, and RubyGems security fixes will be
released for any RubyGems version that shipped inside a currently-supported
Ruby version.

### Bugfix Releases

RubyGems generally releases bugfixes from the master branch. We may mix bug
fixes and new features in the same release. RubyGems does not guarantee it
will ship bugfix releases for previous minor or major versions.

For example, after RubyGems 2.5 is released, the RubyGems team will not
provide non-security fixes for RubyGems 2.4, or any earlier versions.

### Security Releases

Security releases will be made for RubyGems minor versions that were included
in a currently-supported Ruby release.

For example, since RubyGems 2.0 was shipped in Ruby 2.0, RubyGems 2.0 will
receive security fixes until Ruby 2.0 reaches end-of-life.

### Ruby Version Support

When a Ruby version reaches end-of-life the following minor release of
RubyGems will drop backwards compatibility with that Ruby version.

For example, since Ruby 2.2 has reached end-of-life, future RubyGems minor
releases will only support Ruby 2.3 and above. As of this writing RubyGems is
at version 2.7, so when RubyGems 2.8 is released, it will only support Ruby
2.3 and later.

## Release Process

Releases of new versions should follow these steps, to ensure the process is
smooth and no needed steps are missed.

### Steps for security releases

*   Obtain CVE numbers as needed from HackerOne or Red Hat.
*   Agree on a release date with ruby-core, so patches can be backported to
    older Ruby versions as needed.
*   Avoid releasing security updates on Fridays, so platform services don't
    have to work on weekends.
*   Continue with the regular release process below.


### Steps for all releases

*   Confirm milestone on GitHub is complete
*   Update History.txt
*   Update Manifest.txt
*   Create and push git tag
*   Create and push `rubygems-update` gem and tgz
*   Publish blog post


## Committer Access

RubyGems committers may lose their commit privileges if they are inactive for
longer than 12 months. Committer permission may be restored upon request by
having a pull request merged.

This is designed to improve the maintainability of RubyGems by requiring
committers to maintain familiarity with RubyGems activity and to improve the
security of RubyGems by preventing idle committers from having their commit
permissions compromised or exposed.

## Changing These Policies

These policies were set in order to reduce the burden of maintenance and to
keep committers current with existing development and policies. RubyGems work
is primarily volunteer-driven which limits the ability to provide long-term
support. By joining [Ruby Together](https://rubytogether.org) you can help
extend support for older RubyGems versions.
