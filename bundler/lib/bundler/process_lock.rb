# frozen_string_literal: true

module Bundler
  class ProcessLock
    def self.lock(bundle_path = Bundler.bundle_path, timeout: 5)
      lock_file_path = File.join(bundle_path, "bundler.lock")
      has_lock = false
      Bundler.ui.debug("Trying to acquire process lock at #{lock_file_path}")

      File.open(lock_file_path, "w") do |f|
        if within_timeout(timeout) { f.flock(File::LOCK_EX | File::LOCK_NB) }
          has_lock = true
          f.write("#{Process.pid}\n")
          yield
          f.flock(File::LOCK_UN)
        else
          Bundler.ui.error("Another bundler process is installing the dependencies. " \
            "Wait for it to finish and try again.")
        end
      end
    rescue Errno::EACCES, Errno::ENOLCK, Errno::ENOTSUP, Errno::EPERM, Errno::EROFS
      # In the case the user does not have access to
      # create the lock file or is using NFS where
      # locks are not available we skip locking.
      yield
    ensure
      FileUtils.rm_f(lock_file_path) if has_lock
    end

    def self.within_timeout(timeout, wait_for_retry: 0.01)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      loop do
        if yield
          return true
        elsif Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at < timeout
          sleep(wait_for_retry)
        else
          return false
        end
      end
    end
    private_class_method :within_timeout
  end
end
