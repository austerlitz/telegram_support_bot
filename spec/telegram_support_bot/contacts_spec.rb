# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot do
  let(:support_chat_id) { 123_456 }
  let(:user_chat_id) { 789_012 }
  let(:adapter) { instance_double(TelegramSupportBot::Adapters::TelegramBot) }

  before do
    TelegramSupportBot.reset_state_store!
    TelegramSupportBot.configure do |config|
      config.support_chat_id = support_chat_id
      config.adapter = :telegram_bot
      config.request_contact_on_start = true
      config.require_contact_for_support = false
      config.contact_request_message = 'Please share your phone'
      config.contact_received_message = 'Contact saved'
      config.contact_invalid_message = 'Please share your own number'
      config.on_contact_received = nil
    end

    allow(TelegramSupportBot).to receive(:adapter).and_return(adapter)
    allow(adapter).to receive(:send_message)
    allow(adapter).to receive(:forward_message).and_return({ 'message_id' => 555 })

    TelegramSupportBot.message_map.clear
    TelegramSupportBot.reverse_message_map.clear
    TelegramSupportBot.reaction_count_state.clear
    TelegramSupportBot.user_profiles.clear
  end

  describe 'contact onboarding' do
    it 'requests contact on /start when enabled' do
      update = {
        'message' => {
          'message_id' => 1,
          'chat' => { 'id' => user_chat_id },
          'text' => '/start'
        }
      }

      expect(adapter).to receive(:send_message).ordered.with(chat_id: user_chat_id, text: TelegramSupportBot.configuration.welcome_message)
      expect(adapter).to receive(:send_message).ordered.with(
        chat_id: user_chat_id,
        text: 'Please share your phone',
        reply_markup: {
          keyboard: [[{ text: 'Share phone number', request_contact: true }]],
          resize_keyboard: true,
          one_time_keyboard: true
        }
      )

      TelegramSupportBot.process_update(update)
    end

    it 'stores profile and invokes callback when user shares own contact' do
      captured_profiles = []
      TelegramSupportBot.configuration.on_contact_received = ->(profile) { captured_profiles << profile }

      update = {
        'message' => {
          'message_id' => 2,
          'chat' => { 'id' => user_chat_id },
          'from' => {
            'id' => user_chat_id,
            'username' => 'john',
            'first_name' => 'John',
            'last_name' => 'Doe',
            'language_code' => 'en'
          },
          'contact' => {
            'user_id' => user_chat_id,
            'phone_number' => '+15551234567',
            'first_name' => 'John',
            'last_name' => 'Doe'
          }
        }
      }

      expect(adapter).to receive(:send_message).with(
        chat_id: user_chat_id,
        text: 'Contact saved',
        reply_markup: { remove_keyboard: true }
      )

      TelegramSupportBot.process_update(update)

      profile = TelegramSupportBot.user_profile(user_chat_id)
      expect(profile).not_to be_nil
      expect(profile[:phone_number]).to eq('+15551234567')
      expect(captured_profiles).to eq([profile])
    end

    it 'rejects contact when it belongs to a different user id' do
      update = {
        'message' => {
          'message_id' => 3,
          'chat' => { 'id' => user_chat_id },
          'contact' => {
            'user_id' => user_chat_id + 1,
            'phone_number' => '+15550001111'
          }
        }
      }

      expect(adapter).to receive(:send_message).with(
        chat_id: user_chat_id,
        text: 'Please share your own number',
        reply_markup: {
          keyboard: [[{ text: 'Share phone number', request_contact: true }]],
          resize_keyboard: true,
          one_time_keyboard: true
        }
      )

      TelegramSupportBot.process_update(update)
      expect(TelegramSupportBot.user_profile(user_chat_id)).to be_nil
    end

    it 'can require contact before forwarding to support' do
      TelegramSupportBot.configuration.require_contact_for_support = true

      message_update = {
        'message' => {
          'message_id' => 10,
          'chat' => { 'id' => user_chat_id },
          'text' => 'Need help'
        }
      }

      expect(adapter).to receive(:send_message).with(
        chat_id: user_chat_id,
        text: 'Please share your phone',
        reply_markup: {
          keyboard: [[{ text: 'Share phone number', request_contact: true }]],
          resize_keyboard: true,
          one_time_keyboard: true
        }
      )
      expect(adapter).not_to receive(:forward_message)

      TelegramSupportBot.process_update(message_update)
    end
  end
end
