# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot::Configuration do
  it 'allows setting an adapter' do
    TelegramSupportBot.configure do |config|
      config.adapter = :telegram_bot
    end

    expect(TelegramSupportBot.configuration.adapter).to eq(:telegram_bot)
  end

  it 'supports keyed bot configurations while preserving default configuration' do
    TelegramSupportBot.configure do |config|
      config.support_chat_id = 111
    end

    TelegramSupportBot.configure(:partner) do |config|
      config.support_chat_id = 222
    end

    expect(TelegramSupportBot.configuration.support_chat_id).to eq(111)
    expect(TelegramSupportBot.configuration(:partner).support_chat_id).to eq(222)
  end

  it 'supports contact onboarding settings' do
    TelegramSupportBot.configure do |config|
      config.request_contact_on_start = true
      config.require_contact_for_support = true
      config.contact_request_message = 'Share contact'
      config.contact_received_message = 'Saved'
      config.contact_invalid_message = 'Invalid'
      config.forward_start_to_support = true
    end

    expect(TelegramSupportBot.configuration.request_contact_on_start).to eq(true)
    expect(TelegramSupportBot.configuration.require_contact_for_support).to eq(true)
    expect(TelegramSupportBot.configuration.contact_request_message).to eq('Share contact')
    expect(TelegramSupportBot.configuration.contact_received_message).to eq('Saved')
    expect(TelegramSupportBot.configuration.contact_invalid_message).to eq('Invalid')
    expect(TelegramSupportBot.configuration.forward_start_to_support).to eq(true)
  end

  it 'supports host user-command callback setting' do
    callback = ->(**_payload) { true }

    TelegramSupportBot.configure do |config|
      config.on_user_command = callback
    end

    expect(TelegramSupportBot.configuration.on_user_command).to eq(callback)
  end

  it 'supports non-command support chat behavior settings' do
    TelegramSupportBot.configure do |config|
      config.ignore_non_command_messages = false
      config.non_command_message_response = 'Team-only mode enabled'
    end

    expect(TelegramSupportBot.configuration.ignore_non_command_messages).to eq(false)
    expect(TelegramSupportBot.configuration.non_command_message_response).to eq('Team-only mode enabled')
  end

  it 'supports configuring redis state backend' do
    TelegramSupportBot.configure do |config|
      config.state_store = :redis
      config.state_store_options = { url: 'redis://localhost:6379/1' }
      config.mapping_ttl_seconds = 100
      config.reaction_count_ttl_seconds = 50
      config.user_profile_ttl_seconds = 500
      config.processed_update_ttl_seconds = 200
    end

    expect(TelegramSupportBot.configuration.state_store).to eq(:redis)
    expect(TelegramSupportBot.configuration.state_store_options).to eq(url: 'redis://localhost:6379/1')
    expect(TelegramSupportBot.configuration.mapping_ttl_seconds).to eq(100)
    expect(TelegramSupportBot.configuration.reaction_count_ttl_seconds).to eq(50)
    expect(TelegramSupportBot.configuration.user_profile_ttl_seconds).to eq(500)
    expect(TelegramSupportBot.configuration.processed_update_ttl_seconds).to eq(200)
  end
end
