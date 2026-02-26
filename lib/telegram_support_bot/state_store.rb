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

    def self.build(configuration, bot_key: TelegramSupportBot::DEFAULT_BOT_KEY)
      backend = configuration.state_store.to_sym
      options = normalize_options(configuration.state_store_options)

      case backend
      when :memory
        StateStores::Memory.new(
          mapping_ttl_seconds: configuration.mapping_ttl_seconds,
          reaction_count_ttl_seconds: configuration.reaction_count_ttl_seconds,
          user_profile_ttl_seconds: configuration.user_profile_ttl_seconds,
          processed_update_ttl_seconds: configuration.processed_update_ttl_seconds,
          **options
        )
      when :redis
        require_relative 'state_stores/redis'
        options = isolate_redis_namespace(options, bot_key)
        StateStores::Redis.new(
          mapping_ttl_seconds: configuration.mapping_ttl_seconds,
          reaction_count_ttl_seconds: configuration.reaction_count_ttl_seconds,
          user_profile_ttl_seconds: configuration.user_profile_ttl_seconds,
          processed_update_ttl_seconds: configuration.processed_update_ttl_seconds,
          **options
        )
      else
        raise ArgumentError, "Unsupported state store backend: #{backend}"
      end
    end

    def self.normalize_options(options)
      (options || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_sym] = value
      end
    end
    private_class_method :normalize_options

    def self.isolate_redis_namespace(options, bot_key)
      normalized_bot_key = (bot_key || TelegramSupportBot::DEFAULT_BOT_KEY).to_sym
      return options if normalized_bot_key == TelegramSupportBot::DEFAULT_BOT_KEY

      base_namespace = options[:namespace] || StateStores::Redis::DEFAULT_NAMESPACE
      suffix = ":#{normalized_bot_key}"
      namespaced = base_namespace.to_s.end_with?(suffix) ? base_namespace.to_s : "#{base_namespace}#{suffix}"

      options.merge(namespace: namespaced)
    end
    private_class_method :isolate_redis_namespace
  end
end

require_relative 'state_stores/memory'
