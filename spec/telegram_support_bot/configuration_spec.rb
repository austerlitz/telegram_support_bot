# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot::Configuration do
  it 'allows setting an adapter' do
    TelegramSupportBot.configure do |config|
      config.adapter = :telegram_bot
    end

    expect(TelegramSupportBot.configuration.adapter).to eq(:telegram_bot)
  end

  it 'supports contact onboarding settings' do
    TelegramSupportBot.configure do |config|
      config.request_contact_on_start = true
      config.require_contact_for_support = true
      config.contact_request_message = 'Share contact'
      config.contact_received_message = 'Saved'
      config.contact_invalid_message = 'Invalid'
    end

    expect(TelegramSupportBot.configuration.request_contact_on_start).to eq(true)
    expect(TelegramSupportBot.configuration.require_contact_for_support).to eq(true)
    expect(TelegramSupportBot.configuration.contact_request_message).to eq('Share contact')
    expect(TelegramSupportBot.configuration.contact_received_message).to eq('Saved')
    expect(TelegramSupportBot.configuration.contact_invalid_message).to eq('Invalid')
  end

  it 'supports configuring redis state backend' do
    TelegramSupportBot.configure do |config|
      config.state_store = :redis
      config.state_store_options = { url: 'redis://localhost:6379/1' }
      config.mapping_ttl_seconds = 100
      config.reaction_count_ttl_seconds = 50
      config.user_profile_ttl_seconds = 500
    end

    expect(TelegramSupportBot.configuration.state_store).to eq(:redis)
    expect(TelegramSupportBot.configuration.state_store_options).to eq(url: 'redis://localhost:6379/1')
    expect(TelegramSupportBot.configuration.mapping_ttl_seconds).to eq(100)
    expect(TelegramSupportBot.configuration.reaction_count_ttl_seconds).to eq(50)
    expect(TelegramSupportBot.configuration.user_profile_ttl_seconds).to eq(500)
  end
end
