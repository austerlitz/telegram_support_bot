# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot::Configuration do
    it 'allows setting an adapter' do
      TelegramSupportBot.configure do |config|
        config.adapter = :telegram_bot
      end

      expect(TelegramSupportBot.configuration.adapter).to eq(:telegram_bot)
    end
  end


