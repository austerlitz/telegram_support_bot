# frozen_string_literal: true

require 'monitor'

module TelegramSupportBot
  module StateStores
    class Memory
      def initialize(**_options)
        @monitor = Monitor.new
        @message_map = {}
        @reverse_message_map = {}
        @reaction_count_state = {}
        @user_profiles = {}
        @start_forwarded_users = {}
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

      def get_message_mapping(key)
        synchronize { @message_map[normalize_key(key)] }
      end

      def set_message_mapping(key, value)
        synchronize { @message_map[normalize_key(key)] = value }
      end

      def clear_message_mappings
        synchronize { @message_map.clear }
      end

      def message_mappings_size
        synchronize { @message_map.size }
      end

      def get_reverse_mapping(key)
        synchronize { @reverse_message_map[normalize_key(key)] }
      end

      def set_reverse_mapping(key, value)
        synchronize { @reverse_message_map[normalize_key(key)] = value }
      end

      def clear_reverse_mappings
        synchronize { @reverse_message_map.clear }
      end

      def reverse_mappings_size
        synchronize { @reverse_message_map.size }
      end

      def get_reaction_count(key)
        synchronize { @reaction_count_state[normalize_key(key)] }
      end

      def set_reaction_count(key, value)
        synchronize { @reaction_count_state[normalize_key(key)] = value }
      end

      def clear_reaction_counts
        synchronize { @reaction_count_state.clear }
      end

      def reaction_counts_size
        synchronize { @reaction_count_state.size }
      end

      def get_user_profile(key)
        synchronize { @user_profiles[normalize_key(key)] }
      end

      def set_user_profile(key, value)
        synchronize { @user_profiles[normalize_key(key)] = value }
      end

      def clear_user_profiles
        synchronize { @user_profiles.clear }
      end

      def user_profiles_size
        synchronize { @user_profiles.size }
      end

      def get_start_forwarded_user(key)
        synchronize { @start_forwarded_users[normalize_key(key)] }
      end

      def set_start_forwarded_user(key, value)
        synchronize { @start_forwarded_users[normalize_key(key)] = value }
      end

      def clear_start_forwarded_users
        synchronize { @start_forwarded_users.clear }
      end

      def start_forwarded_users_size
        synchronize { @start_forwarded_users.size }
      end

      private

      def synchronize(&block)
        @monitor.synchronize(&block)
      end

      def normalize_key(key)
        key.to_s
      end
    end
  end
end
