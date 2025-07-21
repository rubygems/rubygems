# frozen_string_literal: true

RSpec.describe "bundle update with version constraints" do
  before do
    build_repo2

    install_gemfile <<-G
      source "https://gem.repo2"
      gem "activesupport"
      gem "myrack-obama"
    G
  end

  it "updates with version constraints" do
    update_repo2 do
      build_gem "activesupport", "3.0"
      build_gem "activesupport", "3.1"
      build_gem "activesupport", "4.0"
      build_gem "myrack", "1.2" do |s|
        s.executables = "myrackup"
      end
    end

    bundle "update \"activesupport, >=3.0, <4.0\""
    expect(out).to include("Bundle updated!")
    expect(the_bundle).to include_gems "activesupport 3.1", "myrack-obama 1.0"
  end

  it "updates with mixed constraints and simple names" do
    update_repo2 do
      build_gem "activesupport", "3.0"
      build_gem "activesupport", "3.1"
      build_gem "activesupport", "4.0"
      build_gem "myrack", "1.2" do |s|
        s.executables = "myrackup"
      end
    end

    bundle "update myrack-obama \"activesupport, >=3.0, <4.0\""
    expect(out).to include("Bundle updated!")
    expect(the_bundle).to include_gems "activesupport 3.1", "myrack 1.2", "myrack-obama 1.0"
  end

  it "handles exact version constraints" do
    update_repo2 do
      build_gem "activesupport", "3.0"
      build_gem "activesupport", "3.1"
      build_gem "activesupport", "4.0"
    end

    bundle "update \"activesupport, =3.0\""
    expect(out).to include("Bundle updated!")
    expect(the_bundle).to include_gems "activesupport 3.0"
  end

  it "handles patch version constraints" do
    update_repo2 do
      build_gem "activesupport", "3.0.0"
      build_gem "activesupport", "3.0.1"
      build_gem "activesupport", "3.1.0"
    end

    bundle "update \"activesupport, ~>3.0.0\""
    expect(out).to include("Bundle updated!")
    expect(the_bundle).to include_gems "activesupport 3.0.1"
  end
end 