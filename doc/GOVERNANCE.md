#  Governance of `ruby/rubygems`

The objective of this document is to provide a minimum version of Governance and plan for a more comprehensive iteration later. Governance is **“a well-defined set of norms, written down.”** We intentionally minimize legalistic language and expect this document to be treated as a tool for understanding and collaboration, and not as a tool for “point of order” procedural technicalities.

The Governance defined in this document can (and should) change as norms change and evolve.

## Matz is BDFL

First, we recognize Yukihiro Matsumoto (Matz) as the [BDFL](https://en.wikipedia.org/wiki/Benevolent_dictator_for_life) of Ruby. The `ruby/rubygems`  repository now falls under the domain of Ruby core contributors. If Matz shows a strong preference or wishes to overrule decisions made by members of the `ruby/rubygems`  repository, we will respect his decisions. We will keep him informed of our work and discussions by having them in the open. At this time we do not require his explicit approval or buy-in to move forward with any specific changes (a lack of engagement will not be treated as a blocker). We will weigh changes and features according to how we believe Matz would prefer, and will explicitly seek his input using our best judgment. For example, if we desire a larger breaking change, Matz would likely want to provide input.

Decisions for Ruby core contributors are made via discussions on the bug tracker [https://bugs.ruby-lang.org/](https://bugs.ruby-lang.org/). Posting there can be used as a mechanism for communicating with Matz, or attending a Ruby developer meeting, or asking someone to represent the group at one. Matz currently delegates his authority to Ruby core committers listed at [https://github.com/ruby/ruby/blob/master/doc/maintainers.md#librubygemsrb-librubygems](https://github.com/ruby/ruby/blob/master/doc/maintainers.md#librubygemsrb-librubygems).

While Matz can overrule decisions made by the governance stated in the rest of this document on individual decisions, contributors should not use him as a mechanism to subvert other governance mechanisms. I.e. Please do not harass Matz because everyone else in the proper channels outlined below said “no.”

## Ruby Core Committer Access

All Ruby core contributors are encouraged to participate through regular Issues and Pull Request interactions on the `ruby/rubygems` repository. If a Ruby core contributor wants commit access on the `ruby/rubygems` repository, they are encouraged to use the governance process defined below to gain `committer` team status, which will allow them commit access.

Ruby core contributors may contact an existing `core` member to request `committer` team membership. They may also open up an issue on `ruby/rubygems` stating that they desire commit access, [https://github.com/ruby/rubygems/issues](https://github.com/ruby/rubygems/issues). When possible, a public request is preferred (for visibility and accountability). `ruby/rubygems`  `core` members are encouraged to move quickly and prioritize these requests from Ruby core contributors.

Some Ruby core contributors are already administrators of the repository (described in the  `access` team section) and therefore have the technical capability to commit to the repository already. We kindly ask that they follow the same process and gain explicit `committer` team permission before exercising their existing commit rights. The `core` team membership is encouraged to prioritize access to existing Ruby core committers.

Upstream Ruby has a copy of Rubygems and might require patches occasionally. It’s acceptable to fix these upstream and then backport to the `ruby/rubygems` repo, [for example](https://github.com/ruby/rubygems/pull/8960).

As mentioned in the prior section, Matz can overrule this document. That also means that Matz can direct existing Ruby core members who are on the `access` team to give another developer the ability to commit to the `ruby/rubygems` repository. We ask that any `access` team members follow the suggestions documented in the `access` section below. Specifically by notifying other `access` team members and documenting the change in an appropriate location. We encourage Matz to use this power sparingly, but ultimately place no demands on him and will respect his discretion in using it as he sees fit.

Core (`core`) members of `ruby/rubygems` are not automatically added to Ruby core contributors. That process is described here [https://github.com/ruby/ruby/wiki/Committer-How-To#how-to-register-you-as-a-committer](https://github.com/ruby/ruby/wiki/Committer-How-To#how-to-register-you-as-a-committer).

----

## The `ruby/rubygems` Repository Provisional Governance

When not explicitly directed by Matz, the rest of this document defines the governance expectations of [github.com/ruby/rubygems](http://github.com/ruby/rubygems) participants.

## Provisional status

This document is provisional. It is meant to be replaced so that governance stays relevant and applicable. Those involved in the `ruby/rubygems`  repository governance are encouraged to start drafting a provisional replacement governance model immediately and iterate on it as soon as possible.

## Teams and Membership

Each team, except where explicitly stated as being under the guidance of another team, will be self-managed: a current member proposes a new member, a majority of current members approve the selection, and this outcome (of who is currently on the team) is documented publicly. Any member may voluntarily resign at any time. For non-voluntary removal, the same consensus process is followed.

Team membership is expected to be an active status. Those not actively exercising their status must be placed into a “paused” or “alumni” state (depending on the duration and discretion of the team). The access team should be notified of any changes in team status. Individual teams will determine a process for any “paused” or “alumni” members wishing to regain access.

Team memberships are not mutually exclusive.

### Teams

* Access - controls access mechanism and governance
* Release - controls software releases
* Security - controls security matters
* Core - controls software roadmap
* Committer - controls contributions to the software
* Triage - controls triaging of software issues

## Access Team (`access`)

The access team controls the mechanisms by which other teams have capabilities. i.e. they can give someone commit permissions on GitHub or owner/deploy permissions on RubyGems.org (e.g. https://rubygems.org/gems/bundler or https://rubygems.org/gems/rubygems-update).

The access team members do not need to be members of another team (i.e. someone can have “access” abilities but not be on “core”). By default, those who have the capability to change permissions should NOT assume they can perform the actions themselves. I.e. Just because you can give someone a commit bit, does not mean you have permission to commit freely to that project (unless otherwise stated via appropriate team membership).

Not all access team members will have access to all administrative controls. All Ruby core committers who have administrative privileges over the entire `ruby` namespace are implicitly in this team.

Access changes made by the team must be communicated to all members so it is clear who made the change, what changed, and why. Security permitting, a public audit log of access changes should be kept.

Select members of Ruby Central are currently part of the `access` team. Going forward it is up to Ruby Central to responsibly determine which members should be part of the `access` team. Ruby Central does not dictate membership of any of the other teams outlined below.

Ruby Central should not make permanent changes without explicit request from the team that holds the power to make that change. For example, they should not remove the ability to close issues from someone unless they’ve been directed by the `core` team (this is a power explicitly granted in the `core` team section). Ruby Central member access should be yielded if the individual who holds it no longer has official ties with Ruby Central.

## Release Team (`release`)

Similar to the access team, those who retain the ability to release Ruby, will also be able to release `ruby/rubygems`  Other members may gain access to release Bundler or `ruby/rubygems`  as suggested by the consensus of `core`. Members of the release team are not required to be members of another team. They will coordinate with Security and Core to release.

## Security Team (`security`)

The Security team members will have the ability to recommend the removal of administrative access from any other team member. The access team is expected to respect this request unless they have strong reason to counter. The security team is able to temporarily pause or revoke access if platform and service security depend on the temporary removal, however, only the `access` team can make the removal permanent.

All requested access changes must be accompanied by sufficient justification. Justification must be presented to the person who lost access shortly after their permissions are removed.

Any other team can request the temporary intervention of the security team before voting to remove a member. I.e. if they believe a member may retaliate if a removal vote is requested, and the security team agrees that the justification is sufficient, access may be removed until the vote occurs.

The security team is expected to advise on sensitive requests such as CVE reports.

## Core Team (`core`)

The core team determines the project's vision. This is achieved by mentoring other teams and advising them. Core team members must show a history of sustained contributions prior to being considered for the `core` team. A core member may override a decision about a feature or breaking change made by a `committer` team member. This should be done explicitly, in public (i.e. on the issue or PR), with a sufficient justification stated.

Core team members are expected to mentor and grow the committer base in quality and quantity.

## Committer team (`committer`)

The `committer` team is responsible for fulfilling the vision of core. This is achieved by working with other teams and making direct contributions, as well as merging or closing pull requests. A committer can override a decision about closing an issue or PR made by a `triage` team member. This should be done explicitly, in public, with a sufficient justification stated.

## Triage Team (`triage`)

The triage team manages the “inflow” of issues and pull requests. They have access to close and open issues and pull requests (PRs) as well as other similar privileges, such as tagging issues. Their membership is governed by `core`. Any triage team member can recommend a new member to `core`.
