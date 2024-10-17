# frozen_string_literal: true

RSpec.describe "process lock spec" do
  describe "when an install operation is already holding a process lock" do
    before { FileUtils.mkdir_p(default_bundle_path) }

    it "will not run a second concurrent bundle install until the lock is released" do
      thread = Thread.new do
        Bundler::ProcessLock.lock(default_bundle_path, timeout: 0.1) do
          sleep 1 # ignore quality_spec
          expect(the_bundle).not_to include_gems "myrack 1.0"
        end
      end

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G

      thread.join
      expect(the_bundle).to include_gems "myrack 1.0"
    end

    it "logs messages about locking" do
      mock_ui = double("UI")
      allow(Bundler).to receive(:ui).and_return(mock_ui)
      expect(mock_ui).to receive(:debug).
        with("Trying to acquire process lock at #{default_bundle_path}/bundler.lock").
        twice

      expect(mock_ui).to receive(:error).
        with("Another bundler process is installing the dependencies. " \
          "Wait for it to finish and try again.")

      Bundler::ProcessLock.lock(default_bundle_path, timeout: 0.1) do
        Bundler::ProcessLock.lock(default_bundle_path, timeout: 0.1) do
          sleep 0.5 # ignore quality_spec
        end
      end
    end

    context "when creating a lock raises Errno::ENOTSUP" do
      before { allow(File).to receive(:open).and_raise(Errno::ENOTSUP) }

      it "skips creating the lock file and yields" do
        processed = false
        Bundler::ProcessLock.lock(default_bundle_path) { processed = true }

        expect(processed).to eq true
      end
    end

    context "when creating a lock raises Errno::EPERM" do
      before { allow(File).to receive(:open).and_raise(Errno::EPERM) }

      it "skips creating the lock file and yields" do
        processed = false
        Bundler::ProcessLock.lock(default_bundle_path) { processed = true }

        expect(processed).to eq true
      end
    end

    context "when creating a lock raises Errno::EROFS" do
      before { allow(File).to receive(:open).and_raise(Errno::EROFS) }

      it "skips creating the lock file and yields" do
        processed = false
        Bundler::ProcessLock.lock(default_bundle_path) { processed = true }

        expect(processed).to eq true
      end
    end
  end
end
