# frozen_string_literal: true
require 'spec_helper'
require 'telegram/bot'

RSpec.describe TelegramSupportBot::Adapters::TelegramBot, :telegram_bot do
  let(:chat_id) { '123456' }
  let(:adapter) { described_class.new(token: 'fake_token', support_chat_id: chat_id) }
  let(:text) { 'Hello, world!' }
  let(:message_id) { '123' }
  let(:telegram_mock) { instance_double(Telegram::Bot::Client) }

  before do
    allow(Telegram::Bot::Client).to receive(:new).and_return(telegram_mock)
    allow(telegram_mock).to receive(:send_message)
    allow(telegram_mock).to receive(:forward_message)
  end

  it_behaves_like "a Telegram bot adapter"
end

