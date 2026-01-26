# Issue triage for ruby/rubygems

This document describes how we manage and triage issues and pull requests in the ruby/rubygems repository, which includes both RubyGems and Bundler.

## Overview

Triaging is the process of reviewing tickets opened by users—verifying bugs, categorizing issues, and ensuring enough information is available for reproduction. We use [issue templates](https://github.com/ruby/rubygems/issues/new) and labels to organize work and guide contributors.

Not every ticket will be a bug in our code, but all open tickets indicate room for improvement. This may mean fixing code, clarifying documentation, or improving error messages.

## Triaging existing issues

When examining a ticket, consider these key questions:

- Can you reproduce the issue?
- Are the reproduction steps clearly documented?
- Which versions (RubyGems or Bundler, depending on the issue) exhibit this bug?
- Which operating systems (macOS, Windows, Linux, etc.) are affected?
- Which Ruby versions and implementations (MRI, JRuby, etc.) are affected?

### Triage strategies

- Request complete output when needed (e.g., `gem env` for RubyGems issues, `bundle env` for Bundler issues).
- Attempt to reproduce the issue in your environment; many bugs are version-specific.
- If reproduction is difficult, incrementally match the reporter's setup (Ruby version, gem versions, environment variables, etc.).
- Confirm the reporter is using the latest RubyGems or Bundler (`gem update` or `gem install bundler`).

### Determining issue status

- **Cannot reproduce**: Comment with what you tried; the bug may already be fixed.
- **User feedback needed**: Apply the "user feedback required" label to mark stale issues.
- **Successfully reproduced**: You're ready to fix or assign it. :)

## Fixing a triaged issue

Once you've reproduced and understand an issue, you can help fix it:

1. **Discuss on the issue**: Coordinate with others to avoid duplicate work and gather feedback.
2. **Follow the pull request guide**: See [PULL_REQUESTS.md](PULL_REQUESTS.md).
3. **Write tests**: Commit changes with tests on a named branch in your fork.
4. **Submit a pull request**: See [about pull requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests).

**Note on changelogs**: Do not manually update the changelog in your PR. Our release scripts generate changelogs from PR titles and labels.

## Handling duplicates

If you identify a duplicate ticket, comment on it with the original issue number. For example: "This is a duplicate of #42 and can be closed."

## Managing stale issues

Issues waiting for user feedback may become stale. The process is:

1. After 2–4 weeks without updates: Leave a comment like "Hey :wave:, is this still a problem for you?"
2. If no response within another week or two: Close the ticket.
3. If the reporter responds: Remind them what information you're waiting for.
4. If required details never arrive: Close the ticket.

## Label guide

### Contribution labels

Guide contributors to issues they can take on:

- **good first issue**: Suitable for newcomers; reasonably scoped for someone new to the codebase.
- **help wanted**: Unclaimed work awaiting volunteers.

### Type labels (light green `type:*`)

Describe the type of issue:

- **bug report**: Something broken, confusing, or unexpected.
- **feature request**: Request for a new feature or enhancement.
- **question**: Request for clarification or guidance.
- **cleanup**: Code refactoring or internal improvements.
- **major bump**: Requires a major version increment.
- **administrative**: Project-process or housekeeping tasks.
- **documentation**: Documentation improvements. RubyGems docs: https://github.com/rubygems/guides

### Pull request scope labels (orange `rubygems:*`, blue `bundler:*`)

Describe the scope and impact of PR changes. These are set by maintainers and used to auto-generate changelogs:

- **security fix**: Addresses a security vulnerability.
- **breaking change**: Requires a major version bump.
- **major enhancement**: Backward compatible and noteworthy for changelog.
- **deprecation**: Introduces a deprecation.
- **feature**: Implements a requested feature.
- **performance**: Improves speed or resource usage.
- **documentation**: User-facing documentation improvements.
- **minor enhancements**: Small but user-visible changes.
- **bug fix**: Resolves a reported bug.

### Workflow / status labels (light yellow `status:*`)

Indicate issue/PR state in progression from submission to closure:

- **triage**: Needs maintainer review and labeling.
- **confirmed**: Accepted as valid; not yet ready for work.
- **ready**: Open for collaboration with a described approach.
- **working**: Assigned and in progress.
- **user feedback required**: Blocked waiting on reporter information.
- **blocked / backlog**: Paused due to external dependency or decision.

### Closed reason labels (maroon `closed:*`)

Why an issue/PR was closed without resolution. Always include context in comments:

- **duplicate**: References an existing issue.
- **abandoned**: Aged out or no longer applicable.
- **declined**: Will not be fixed or merged.
- **deprecated**: No longer relevant to maintained code.
- **discussion**: Not actionable; kept for conversation.

### Category labels (blue `category:*`)

Aspects of the codebase. Not all issues are categorized:

- **gemspec**: Gem specification.
- **API**: Public RubyGems code API (not network/HTTP).
- **command**: Related to `Gem::Commands`.
- **install**: Gem installation.
- **documentation**: Docs and guides.

### Platform labels (purple `platform:*`)

For platform-specific issues or PRs:

- **windows**, **java**, **osx**, **linux**
