module Gem

  class IncrementalFetcher
    def initialize(source_uri, fetcher, cache_manager)
      @source_uri = source_uri
      @fetcher = fetcher
      @manager = cache_manager
    end

    def size
      @fetcher.size
    end

    def source_index
      entry = @manager.cache_data[@source_uri]
      if entry.nil?
	entry =
	  @manager.cache_data[@source_uri] =
	  SourceInfoCacheEntry.new(SourceIndex.new,0)
      end
      update_cache(entry) if entry.size != remote_size
      entry.source_index
    end

    private

    # Return the size of the remote source index.  Cache the value for later use.
    def remote_size
      @remote_size ||= @fetcher.size
    end

    # Update the cache entry
    def update_cache(entry)
      index_list = get_quick_index
      remove_extra(entry.source_index, index_list)
      update_with_missing(entry.source_index, index_list)
      @manager.flush
    rescue OperationNotSupportedError => ex
      si = @fetcher.source_index
      entry.replace_source_index(si, remote_size)
    end

    def remove_extra(source_index, spec_names)
      dictionary = spec_names.inject({}) { |h, k| h[k] = true; h }
      source_index.each do |name, spec|
	if dictionary[name].nil?
	  source_index.remove_spec(name)
	  @manager.update
	end
      end
    end

    def update_with_missing(source_index, spec_names)
      spec_names.each do |spec_name|
	spec = source_index.specification(spec_name)
	if spec.nil?
	  zipped_yaml = fetch("/quick/" + spec_name + ".gemspec.rz")
	  gemspec = YAML.load(unzip(zipped_yaml))
	  source_index.add_spec(gemspec)
	  @manager.update
	end
      end
    end

    def get_quick_index
      zipped_index = fetch("/quick/index.rz")
      unzip(zipped_index).split("\n")
    rescue ::Exception => ex
      fail OperationNotSupportedError.new("No quick index found: " + ex.message)
    end

    def fetch(uri)
      @fetcher.fetch_path(uri)
    end

    def unzip(string)
      require 'zlib'
      Zlib::Inflate.inflate(string)
    end
  end
end
