# Merging a PR

Bundler requires all CI status checks to pass before a PR can me merged. So make
sure that's the case before merging.

Also, bundler manages the changelog automatically using information from merged
PRs. So, if a PR has user visible changes that should be included in a future
release, make sure the following information is accurate:

* The PR has a good descriptive title. That will be the wording for the
  corresponding changelog entry.

* The PR has an accurate label. If a PR is to be included in the changelog since
  it has user visible changes, the label must be one of the following:

  * "bundler: security fix"
  * "bundler: breaking change"
  * "bundler: major enhancement"
  * "bundler: deprecation"
  * "bundler: feature"
  * "bundler: performance"
  * "bundler: documentation"
  * "bundler: minor enhancement"
  * "bundler: bug fix"

  This label will indicate the section in the changelog that the PR will take,
  and it will also be automatically used by our release tasks for backporting.
  The labels that should be backported only to patch level releases, and to
  either patch level or minor releases can be configured in the `.changelog.yml`
  file.

  If for some reason you need a PR to be backported to a stable branch, but it
  doesn't have any user visible changes, apply the "bundler: skip changelog"
  label to it so that our release scripts know about that.

Finally, don't forget to review the changes in detail. Make sure you try them
locally if they are not trivial and make sure you request changes and ask as
many questions as needed until you are convinced that including the changes into
bundler is a strict improvement and will not make things regress in any way.
