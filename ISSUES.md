# Issue Management

The goal of issue management is to organize the work that needs to be
done when working on a project, by allowing users to report bugs,
request features or documentation, and start discussions.

To simplify that task, issues have labels. The purpose of labels is to
group issues in ways developers find useful. The obvious examples being
bug reports and feature requests.

This document is intended as a guide to help you understand what labels
on a given issue mean, or to help you choose labels for a new issue.

Labels on this repository are grouped, using the section before the
first colon in an issue name (e.g. the group for "foo: bar" would be "foo").

---

RubyGems has a lot of issue labels, and it can be a bit overwhelming, so
this document only includes groups and labels which are consistently used.

Issue groups:

* [category](#category) &mdash; what part of the codebase an issue
  relates to.
* [platform](#platform) &mdash; which platform an issue applies to (if
  it's specific to one).
* [status](#status) &mdash; is the issue ready to be worked on?
* [type](#type) &mdash; what type of issue is it?

---

## Labels

### category

A label group specifying what part of the codebase an issue relates to.

#### category: API

Issues related to the RubyGems API.

#### category: command

Issues related to the RubyGems command itself.

#### category: #gem or #require

Issues related to the `gem` or `require` methods.

#### category: gem spec

Issues related to gem specs.

#### category: install

Issues related to installing gems.

### platform

The platform an issue applies to, if it applies to a specific platform.
If it applies to more than one label, don't add one of these labels.

### status

For determining if an issue is being worked on and/or if you can begin
work.

#### status: blocked / backlog

An issue are blocked if work must be done independent of that issue
before it can be worked on. E.g., if it relies on another issue, or
requires changes to rubygems.org.


#### status: ready

Issues that are ready to be worked on.

#### status: triage

Issues that have yet to be triaged (that is, had the appropriate labels
applied to them).

#### status: user feedback required

Issues that require further feedback from one of the participants in the
issue. (This is often, but not always, the person who opened it.)

#### status: working

Issues that are currently being worked on.

### type

#### type: bug report

Issues that are bug reports.

#### type: documentation

Issues related to documentation of the project.

#### type: feature request

Issues that are feature requests.

#### type: major bump

Issues that would cause a backwards-incompatible API change, and thus
would require incrementing the major version number of the project.

(See also, https://semver.org)

#### type: question

Issues which are questions or discussions.
