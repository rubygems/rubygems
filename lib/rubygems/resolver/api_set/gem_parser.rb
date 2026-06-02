# frozen_string_literal: true

class Gem::Resolver::APISet::GemParser
  def parse(line)
    version_and_platform, rest = line.split(" ", 2)
    version, platform = version_and_platform.split("-", 2)
    dependencies, requirements = rest.split("|", 2).map! {|s| s.split(",") } if rest
    dependencies = dependencies ? dependencies.map! {|d| parse_dependency(d) } : []
    requirements = requirements ? requirements.map! {|d| parse_dependency(d) } : []

    artifact_id = nil
    explicit_platform = find_requirement(requirements, "platform")
    if explicit_platform && platform
      artifact_id = platform
      platform = explicit_platform
      requirements << [-"artifact_id", [artifact_id]]
    end

    [version, platform, dependencies, requirements, artifact_id]
  end

  private

  def find_requirement(requirements, name)
    requirement = requirements.find {|key, _| key == name }
    requirement&.last&.last
  end

  def parse_dependency(string)
    dependency = string.split(":")
    dependency[-1] = dependency[-1].split("&") if dependency.size > 1
    dependency[0] = -dependency[0]
    dependency
  end
end
