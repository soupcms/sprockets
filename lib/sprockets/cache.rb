require 'sprockets/utils'

module Sprockets
  # Public: Wrapper interface to backend cache stores. Ensures a consistent API
  # even when the backend uses get/set or read/write.
  #
  # Public cache interface
  #
  # Always assign the backend store instance to Environment#cache=.
  #
  #     environment.cache = Sprockets::Cache::MemoryStore.new(1000)
  #
  # Environment#cache will always return a wrapped Cache interface. See the
  # methods marked public on this class.
  #
  #
  # Backend cache interface
  #
  # The Backend cache store must implement two methods.
  #
  # get(key)
  #
  #   key - An opaque String with a length less than 250 characters.
  #
  #   Returns an JSON serializable object.
  #
  # set(key, value)
  #
  #   Will only be called once per key. Setting a key "foo" with value "bar",
  #   then later key "foo" with value "baz" is an undefined behavior.
  #
  #   key   - An opaque String with a length less than 250 characters.
  #   value - A JSON serializable object.
  #
  #   Returns argument value.
  #
  class Cache
    # Builtin cache stores.
    autoload :FileStore,   'sprockets/cache/file_store'
    autoload :MemoryStore, 'sprockets/cache/memory_store'
    autoload :NullStore,   'sprockets/cache/null_store'

    # Internal: Cache key version for this class. Rarely should have to change
    # unless the cache format radically changes. Will be bump on major version
    # releases though.
    VERSION = '3.0'

    # Internal: Wrap a backend cache store.
    #
    # Always assign a backend cache store instance to Environment#cache= and
    # use Environment#cache to retreive a wrapped interface.
    #
    # cache - A compatible backend cache store instance.
    def initialize(cache = nil)
      @cache_wrapper = get_cache_wrapper(cache)
    end

    # Public: Prefer API to retrieve and set values in the cache store.
    #
    # key   - JSON serializable key
    # block -
    #   Must return a consistent JSON serializable object for the given key.
    #
    # Examples
    #
    #   cache.fetch("foo") { "bar" }
    #
    # Returns a JSON serializable object.
    def fetch(key)
      expanded_key = expand_key(key)
      value = @cache_wrapper.get(expanded_key)
      if value.nil?
        value = yield
        @cache_wrapper.set(expanded_key, value)
      end
      value
    end

    # Public: Low level API to retrieve item directly from the backend cache
    # store.
    #
    # This API may be used publicaly, but may have undefined behavior
    # depending on the backend store being used. Therefore it must be used
    # with caution, which is why its prefixed with an underscore. Prefer the
    # Cache#fetch API over using this.
    #
    # key   - JSON serializable key
    # value - A consistent JSON serializable object for the given key. Setting
    #         a different value for the given key has undefined behavior.
    #
    # Returns a JSON serializable object or nil if there was a cache miss.
    def _get(key)
      @cache_wrapper.get(expand_key(key))
    end

    # Public: Low level API to set item directly to the backend cache store.
    #
    # This API may be used publicaly, but may have undefined behavior
    # depending on the backend store being used. Therefore it must be used
    # with caution, which is why its prefixed with an underscore. Prefer the
    # Cache#fetch API over using this.
    #
    # key - JSON serializable key
    #
    # Returns the value argument.
    def _set(key, value)
      @cache_wrapper.set(expand_key(key), value)
    end

    private
      # Internal: Expand object cache key into a short String key.
      #
      # The String should be under 250 characters so its compatible with
      # Memcache.
      #
      # key - JSON serializable key
      #
      # Returns a String with a length less than 250 characters.
      def expand_key(key)
        "sprockets/v#{VERSION}/#{Utils.hexdigest(key)}"
      end

      def get_cache_wrapper(cache)
        if cache.is_a?(Cache)
          cache

        # `Cache#get(key)` for Memcache
        elsif cache.respond_to?(:get)
          GetWrapper.new(cache)

        # `Cache#[key]` so `Hash` can be used
        elsif cache.respond_to?(:[])
          HashWrapper.new(cache)

        # `Cache#read(key)` for `ActiveSupport::Cache` support
        elsif cache.respond_to?(:read)
          ReadWriteWrapper.new(cache)

        else
          cache = Sprockets::Cache::NullStore.new
          GetWrapper.new(cache)
        end
      end

      class Wrapper < Struct.new(:cache)
      end

      class GetWrapper < Wrapper
        def get(key)
          cache.get(key)
        end

        def set(key, value)
          cache.set(key, value)
        end
      end

      class HashWrapper < Wrapper
        def get(key)
          cache[key]
        end

        def set(key, value)
          cache[key] = value
        end
      end

      class ReadWriteWrapper < Wrapper
        def get(key)
          cache.read(key)
        end

        def set(key, value)
          cache.write(key, value)
        end
      end
  end
end
