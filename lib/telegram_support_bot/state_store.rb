# frozen_string_literal: true

module TelegramSupportBot
  module StateStore
    class MapProxy
      def initialize(get_proc:, set_proc:, clear_proc:, size_proc:)
        @get_proc = get_proc
        @set_proc = set_proc
        @clear_proc = clear_proc
        @size_proc = size_proc
      end

      def [](key)
        @get_proc.call(key)
      end

      def []=(key, value)
        @set_proc.call(key, value)
      end

      def clear
        @clear_proc.call
      end

      def size
        @size_proc.call
      end
    end

    def self.build(configuration)
      backend = configuration.state_store.to_sym
      options = configuration.state_store_options || {}

      case backend
      when :memory
        StateStores::Memory.new(
          mapping_ttl_seconds: configuration.mapping_ttl_seconds,
          reaction_count_ttl_seconds: configuration.reaction_count_ttl_seconds,
          user_profile_ttl_seconds: configuration.user_profile_ttl_seconds,
          **options
        )
      when :redis
        require_relative 'state_stores/redis'
        StateStores::Redis.new(
          mapping_ttl_seconds: configuration.mapping_ttl_seconds,
          reaction_count_ttl_seconds: configuration.reaction_count_ttl_seconds,
          user_profile_ttl_seconds: configuration.user_profile_ttl_seconds,
          **options
        )
      else
        raise ArgumentError, "Unsupported state store backend: #{backend}"
      end
    end
  end
end

require_relative 'state_stores/memory'
