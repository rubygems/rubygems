#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

module Gem

  ####################################################################
  class IncrementalFetcher
    include Gem::DefaultUserInteraction

    # Initialize an incremental source fetcher.
    def initialize(source_uri, fetcher, cache_manager)
      @source_uri = source_uri
      @fetcher = fetcher
      @manager = cache_manager
    end

    # Return the size of the source index for the gem source.
    def size
      @fetcher.size
    end

    # Return the source index for the gem source.
    def source_index
      entry = get_entry
      if entry.nil?
	entry =
	  @manager.cache_data[@source_uri] =
	  SourceInfoCacheEntry.new(SourceIndex.new,0)
      end
      update_cache(entry) if entry.size != remote_size
      entry.source_index
    end

    # Fetch the given path from the gem source.
    def fetch_path(path)
      @fetcher.fetch_path(path)
    end

    private

    def get_entry
      result = @manager.cache_data[@source_uri]
      case result
      when SourceInfoCacheEntry, nil
	# do nothing ... everything is fine
      when Hash
	result = SourceInfoCacheEntry.new(result['source_index'], result['size'])
	@manager.cache_data[@source_uri] = result	
      else
	fail "Unexpected type (#{result.class}) for SourceInfoCache entry"
      end
      result	
    end

    # Return the size of the remote source index.  Cache the value for later use.
    def remote_size
      @remote_size ||= @fetcher.size
    end

    INCREMENTAL_THRESHHOLD = 50

    # Update the cache entry.  Use the incremental method unless 
    def update_cache(entry)
      use_incremental = false
      begin
        index_list = get_quick_index
        remove_extra(entry.source_index, index_list)
        missing_list = find_missing(entry.source_index, index_list)
        use_incremental = missing_list.size <= INCREMENTAL_THRESHHOLD
      rescue OperationNotSupportedError => ex
        use_incremental = false
      end
      if use_incremental
        update_with_missing(entry.source_index, missing_list)
        @manager.flush
      else
        si = @fetcher.source_index
        entry.replace_source_index(si, remote_size)
      end
    end

    # Remove extra entries from the cached source index.
    def remove_extra(source_index, spec_names)
      dictionary = spec_names.inject({}) { |h, k| h[k] = true; h }
      source_index.each do |name, spec|
	if dictionary[name].nil?
	  source_index.remove_spec(name)
	  @manager.update
	end
      end
    end

    # Make a list of full names for all the missing gemspecs.
    def find_missing(source_index, spec_names)
      spec_names.find_all { |full_name|
	source_index.specification(full_name).nil?
      }
    end

    # Update the cached source index with the missing names.
    def update_with_missing(source_index, missing_names)
      progress = ui.progress_reporter(missing_names.size,
	"Need to update #{missing_names.size} gems from #{@source_uri}")
      missing_names.each do |spec_name|
	begin
	  zipped_yaml = fetch_path("/quick/" + spec_name + ".gemspec.rz")
	  gemspec = YAML.load(unzip(zipped_yaml))
	  source_index.add_spec(gemspec)
	  @manager.update
	  progress.updated(spec_name)
	rescue RuntimeError => ex
	  ui.say "Failed to download spec for #{spec_name} from #{@source_uri}"
	end
      end
      progress.done
      progress.count
    end

    # Get the quick index needed for incremental updates.
    def get_quick_index
      zipped_index = fetch_path("/quick/index.rz")
      unzip(zipped_index).split("\n")
    rescue ::Exception => ex
      fail OperationNotSupportedError.new("No quick index found: " + ex.message)
    end

    # Unzip the given string.
    def unzip(string)
      require 'zlib'
      Zlib::Inflate.inflate(string)
    end
  end
end
