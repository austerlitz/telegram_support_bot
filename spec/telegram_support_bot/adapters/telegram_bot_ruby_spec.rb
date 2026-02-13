# frozen_string_literal: true
require 'spec_helper'
require 'telegram/bot'


RSpec.describe TelegramSupportBot::Adapters::TelegramBotRuby, :telegram_bot_ruby do
  describe '#send_message' do
    it 'calls the Telegram Bot API to send a message' do
      client = double('Telegram::Bot::Client')
      allow(Telegram::Bot::Client).to receive(:new).and_return(client)
      allow(client).to receive(:api).and_return(double(send_message: true))

      adapter = described_class.new(token: 'fake_token')
      expect(adapter.send_message(chat_id: '123', text: 'Hello')).to be true
    end
  end

  describe '#set_message_reaction' do
    it 'calls the Telegram Bot API to set a message reaction' do
      client = double('Telegram::Bot::Client')
      allow(Telegram::Bot::Client).to receive(:new).and_return(client)
      allow(client).to receive(:api).and_return(double(set_message_reaction: true))

      adapter = described_class.new(token: 'fake_token')
      reaction = [{ 'type' => 'emoji', 'emoji' => '👍' }]
      expect(adapter.set_message_reaction(chat_id: '123', message_id: '456', reaction: reaction)).to be true
    end
  end
end
