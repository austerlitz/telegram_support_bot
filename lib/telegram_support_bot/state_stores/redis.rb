# frozen_string_literal: true

require 'json'

module TelegramSupportBot
  module StateStores
    class Redis
      DEFAULT_NAMESPACE = 'telegram_support_bot'

      def initialize(url: nil, redis: nil, namespace: DEFAULT_NAMESPACE,
                     mapping_ttl_seconds: nil, reaction_count_ttl_seconds: nil, user_profile_ttl_seconds: nil,
                     processed_update_ttl_seconds: nil, **_options)
        @redis = redis || begin
          require 'redis'
          ::Redis.new(url: url)
        rescue LoadError => e
          raise LoadError, "Redis backend requires the 'redis' gem. #{e.message}"
        end
        @namespace = namespace
        @mapping_ttl_seconds = mapping_ttl_seconds
        @reaction_count_ttl_seconds = reaction_count_ttl_seconds
        @user_profile_ttl_seconds = user_profile_ttl_seconds
        @processed_update_ttl_seconds = processed_update_ttl_seconds
      end

      def message_map
        @message_map_proxy ||= StateStore::MapProxy.new(
          get_proc:   ->(key) { get_message_mapping(key) },
          set_proc:   ->(key, value) { set_message_mapping(key, value) },
          clear_proc: -> { clear_message_mappings },
          size_proc:  -> { message_mappings_size }
        )
      end

      def reverse_message_map
        @reverse_map_proxy ||= StateStore::MapProxy.new(
          get_proc:   ->(key) { get_reverse_mapping(key) },
          set_proc:   ->(key, value) { set_reverse_mapping(key, value) },
          clear_proc: -> { clear_reverse_mappings },
          size_proc:  -> { reverse_mappings_size }
        )
      end

      def reaction_count_state
        @reaction_state_proxy ||= StateStore::MapProxy.new(
          get_proc:   ->(key) { get_reaction_count(key) },
          set_proc:   ->(key, value) { set_reaction_count(key, value) },
          clear_proc: -> { clear_reaction_counts },
          size_proc:  -> { reaction_counts_size }
        )
      end

      def user_profiles
        @user_profiles_proxy ||= StateStore::MapProxy.new(
          get_proc:   ->(key) { get_user_profile(key) },
          set_proc:   ->(key, value) { set_user_profile(key, value) },
          clear_proc: -> { clear_user_profiles },
          size_proc:  -> { user_profiles_size }
        )
      end

      def start_forwarded_users
        @start_forwarded_users_proxy ||= StateStore::MapProxy.new(
          get_proc:   ->(key) { get_start_forwarded_user(key) },
          set_proc:   ->(key, value) { set_start_forwarded_user(key, value) },
          clear_proc: -> { clear_start_forwarded_users },
          size_proc:  -> { start_forwarded_users_size }
        )
      end

      def processed_updates
        @processed_updates_proxy ||= StateStore::MapProxy.new(
          get_proc:   ->(key) { get_processed_update(key) },
          set_proc:   ->(key, value) { set_processed_update(key, value) },
          clear_proc: -> { clear_processed_updates },
          size_proc:  -> { processed_updates_size }
        )
      end

      def get_message_mapping(key)
        payload = parse_json(@redis.get(map_key(:message_map, key)))
        symbolize_hash(payload)
      end

      def set_message_mapping(key, value)
        write_json(map_key(:message_map, key), value, @mapping_ttl_seconds)
      end

      def clear_message_mappings
        delete_by_prefix(prefix(:message_map))
      end

      def message_mappings_size
        count_by_prefix(prefix(:message_map))
      end

      def get_reverse_mapping(key)
        raw = @redis.get(map_key(:reverse_message_map, key))
        coerce_scalar(raw)
      end

      def set_reverse_mapping(key, value)
        write_scalar(map_key(:reverse_message_map, key), value, @mapping_ttl_seconds)
      end

      def clear_reverse_mappings
        delete_by_prefix(prefix(:reverse_message_map))
      end

      def reverse_mappings_size
        count_by_prefix(prefix(:reverse_message_map))
      end

      def get_reaction_count(key)
        parse_json(@redis.get(map_key(:reaction_count_state, key)))
      end

      def set_reaction_count(key, value)
        write_json(map_key(:reaction_count_state, key), value, @reaction_count_ttl_seconds)
      end

      def clear_reaction_counts
        delete_by_prefix(prefix(:reaction_count_state))
      end

      def reaction_counts_size
        count_by_prefix(prefix(:reaction_count_state))
      end

      def get_user_profile(key)
        payload = parse_json(@redis.get(map_key(:user_profiles, key)))
        symbolize_hash(payload)
      end

      def set_user_profile(key, value)
        write_json(map_key(:user_profiles, key), value, @user_profile_ttl_seconds)
      end

      def clear_user_profiles
        delete_by_prefix(prefix(:user_profiles))
      end

      def user_profiles_size
        count_by_prefix(prefix(:user_profiles))
      end

      def get_start_forwarded_user(key)
        parse_json(@redis.get(map_key(:start_forwarded_users, key)))
      end

      def set_start_forwarded_user(key, value)
        write_json(map_key(:start_forwarded_users, key), value, @user_profile_ttl_seconds)
      end

      def clear_start_forwarded_users
        delete_by_prefix(prefix(:start_forwarded_users))
      end

      def start_forwarded_users_size
        count_by_prefix(prefix(:start_forwarded_users))
      end

      def get_processed_update(key)
        parse_json(@redis.get(map_key(:processed_updates, key)))
      end

      def set_processed_update(key, value)
        write_json(map_key(:processed_updates, key), value, @processed_update_ttl_seconds)
      end

      def clear_processed_updates
        delete_by_prefix(prefix(:processed_updates))
      end

      def processed_updates_size
        count_by_prefix(prefix(:processed_updates))
      end

      private

      def prefix(name)
        "#{@namespace}:#{name}:"
      end

      def map_key(name, key)
        "#{prefix(name)}#{key}"
      end

      def write_json(key, value, ttl_seconds)
        payload = JSON.generate(value)
        write_raw(key, payload, ttl_seconds)
      end

      def write_scalar(key, value, ttl_seconds)
        write_raw(key, value.to_s, ttl_seconds)
      end

      def write_raw(key, value, ttl_seconds)
        @redis.set(key, value)
        @redis.expire(key, ttl_seconds.to_i) if ttl_seconds && ttl_seconds.to_i.positive?
      end

      def parse_json(raw)
        return nil if raw.nil?

        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end

      def symbolize_hash(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), memo| memo[k.to_sym] = symbolize_hash(v) }
        when Array
          obj.map { |item| symbolize_hash(item) }
        else
          obj
        end
      end

      def coerce_scalar(raw)
        return nil if raw.nil?

        return raw.to_i if /\A-?\d+\z/.match?(raw)

        raw
      end

      def delete_by_prefix(key_prefix)
        scan_each(key_prefix) do |key|
          @redis.del(key)
        end
      end

      def count_by_prefix(key_prefix)
        count = 0
        scan_each(key_prefix) { count += 1 }
        count
      end

      def scan_each(key_prefix)
        cursor = '0'
        pattern = "#{key_prefix}*"

        loop do
          cursor, keys = @redis.scan(cursor, match: pattern, count: 1000)
          keys.each { |key| yield key }
          break if cursor == '0'
        end
      end
    end
  end
end
