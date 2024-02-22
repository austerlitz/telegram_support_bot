# frozen_string_literal: true
require 'spec_helper'
require 'telegram/bot'


RSpec.describe TelegramSupportBot::Adapters::TelegramBotRubyAdapter, :telegram_bot_ruby do
  describe '#send_message' do
    it 'calls the Telegram Bot API to send a message' do
      client = instance_double('Telegram::Bot::Client')
      allow(Telegram::Bot::Client).to receive(:new).and_return(client)
      allow(client).to receive(:api).and_return(double(send_message: true))

      adapter = described_class.new(token: 'fake_token')
      expect(adapter.send_message(chat_id: '123', text: 'Hello')).to be true
    end
  end
end
