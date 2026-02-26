# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot do
  class FakeRedis
    def initialize
      @data = {}
    end

    def get(key)
      @data[key]
    end

    def set(key, value)
      @data[key] = value
      'OK'
    end

    def expire(_key, _seconds)
      true
    end

    def del(key)
      @data.delete(key)
    end

    def scan(cursor, match:, count: 1000)
      keys = @data.keys.select { |key| File.fnmatch(match, key) }.first(count)
      [cursor == '0' ? '0' : cursor, keys]
    end

    def keys
      @data.keys
    end
  end

  describe 'state store backends' do
    it 'supports redis-backed mapping lookup across store reinitialization' do
      fake_redis = FakeRedis.new
      TelegramSupportBot.reset_state_store!

      TelegramSupportBot.configure do |config|
        config.state_store = :redis
        config.state_store_options = { redis: fake_redis, namespace: 'tsb_test' }
      end

      TelegramSupportBot.message_map[123] = { chat_id: 42, message_id: 88 }
      TelegramSupportBot.reverse_message_map['42:88'] = 123
      TelegramSupportBot.start_forwarded_users[42] = true
      TelegramSupportBot.processed_updates[9001] = true

      TelegramSupportBot.reset_state_store!

      expect(TelegramSupportBot.message_map[123]).to eq(chat_id: 42, message_id: 88)
      expect(TelegramSupportBot.reverse_message_map['42:88']).to eq(123)
      expect(TelegramSupportBot.start_forwarded_users[42]).to eq(true)
      expect(TelegramSupportBot.processed_updates[9001]).to eq(true)
    end

    it 'isolates redis namespace by bot key for non-default bots' do
      fake_redis = FakeRedis.new

      TelegramSupportBot.configure do |config|
        config.state_store = :redis
        config.state_store_options = { redis: fake_redis }
      end

      TelegramSupportBot.configure(:partner) do |config|
        config.state_store = :redis
        config.state_store_options = { redis: fake_redis }
      end

      TelegramSupportBot.message_map[100] = { chat_id: 1, message_id: 10 }
      TelegramSupportBot.message_map(:partner)[100] = { chat_id: 2, message_id: 20 }
      TelegramSupportBot.start_forwarded_users[1] = true
      TelegramSupportBot.start_forwarded_users(:partner)[2] = true
      TelegramSupportBot.processed_updates[111] = true
      TelegramSupportBot.processed_updates(:partner)[222] = true

      expect(TelegramSupportBot.message_map[100]).to eq(chat_id: 1, message_id: 10)
      expect(TelegramSupportBot.message_map(:partner)[100]).to eq(chat_id: 2, message_id: 20)
      expect(TelegramSupportBot.start_forwarded_users[1]).to eq(true)
      expect(TelegramSupportBot.start_forwarded_users(:partner)[2]).to eq(true)
      expect(TelegramSupportBot.processed_updates[111]).to eq(true)
      expect(TelegramSupportBot.processed_updates(:partner)[222]).to eq(true)
      expect(fake_redis.keys).to include('telegram_support_bot:message_map:100')
      expect(fake_redis.keys).to include('telegram_support_bot:partner:message_map:100')
      expect(fake_redis.keys).to include('telegram_support_bot:start_forwarded_users:1')
      expect(fake_redis.keys).to include('telegram_support_bot:partner:start_forwarded_users:2')
      expect(fake_redis.keys).to include('telegram_support_bot:processed_updates:111')
      expect(fake_redis.keys).to include('telegram_support_bot:partner:processed_updates:222')
    end
  end
end
