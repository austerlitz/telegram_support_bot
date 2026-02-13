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

      TelegramSupportBot.reset_state_store!

      expect(TelegramSupportBot.message_map[123]).to eq(chat_id: 42, message_id: 88)
      expect(TelegramSupportBot.reverse_message_map['42:88']).to eq(123)
    end
  end
end
