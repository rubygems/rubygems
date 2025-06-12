# Team changes

This file documents how to add and remove team members. For the rules governing adding and removing team members, see [POLICIES](../POLICIES.md).

## Adding a new team member

Interested in adding someone to the team? Here's the process.

1. An existing team member nominates a potential team member to the rest of the team.
2. The existing team reaches consensus about whether to invite the potential member.
3. The nominator asks the potential member if they would like to join the team.
4. The nominator also sends the candidate a link to [POLICIES](../POLICIES.md) as an orientation for being on the team.
5. If the potential member accepts:
    - Invite them to the maintainers Slack channel
    - Add them to the [maintainers team][org_team] on GitHub
    - Add them to the [Team page][team] on bundler.io, in the [maintainers list][maintainers]
    - Add them to the [list of team members][list] in `contributors.rake`
    - Add them to the authors list in `bundler.gemspec` && `rubygems-update.gemspec`
    - Add them to the owners list on RubyGems.org by running
      ```
      $ gem owner -a EMAIL bundler
      ```


## Removing a team member

When the conditions in [POLICIES](../POLICIES.md#maintainer-team-guidelines) are met, or when team members choose to retire, here's how to remove someone from the team.

- Remove them from the owners list on RubyGems.org by running
  ```
  $ gem owner -r EMAIL bundler
  ```
- Remove their entry on the [Team page][team] on bundler.io, in the [maintainers list][maintainers]
- Remove them from the [list of team members][list] in `contributors.rake`
- Remove them from the [maintainers team][org_team] on GitHub
- Remove them from the maintainers Slack channel

[org_team]: https://github.com/orgs/rubygems/teams/maintainers/members
[team]: https://bundler.io/contributors.html
[maintainers]: https://github.com/rubygems/bundler-site/blob/f00eb65da0697c2cb0e7b4d6e5ba47ecc1538eb2/source/contributors.html.haml#L25
[list]: https://github.com/rubygems/bundler-site/blob/f00eb65da0697c2cb0e7b4d6e5ba47ecc1538eb2/lib/tasks/contributors.rake#L8
