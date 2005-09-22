module Gem

  class OperationNotSupportedError < Gem::Exception
  end

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
      fail OperationNotSupportedError, "No quick index found"
    end
  end
end
