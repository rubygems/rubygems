module Gem

  class IncrementalFetcher
    def initialize(source_uri, fetcher, cache_manager)
      @source_uri = source_uri
      @fetcher = fetcher
      @cache_manager = cache_manager
    end

    def size
      @fetcher.size
    end

    def source_index
      quick_index = @fetcher.fetch_path("quick/index.gz")
    rescue ::Exception => ex
      fail OperationNotSupportedError.new("No quick index found")
    end
  end
end
