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
    TelegramSupportBot.start_forwarded_users.clear
    TelegramSupportBot.processed_updates.clear
  end

  describe 'contact onboarding' do
    shared_examples 'start command welcome flow' do |text|
      it "treats #{text.inspect} as /start" do
        update = {
          'message' => {
            'message_id' => 1,
            'chat' => { 'id' => user_chat_id },
            'text' => text
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
        expect(adapter).not_to receive(:forward_message)

        TelegramSupportBot.process_update(update)
      end
    end

    include_examples 'start command welcome flow', '/start'
    include_examples 'start command welcome flow', '/start lead_123_456'
    include_examples 'start command welcome flow', '/start@my_bot'
    include_examples 'start command welcome flow', '/start@my_bot lead_123_456'

    it 'does not pass /start to host command callback' do
      callback = double('user_command_callback')
      allow(callback).to receive(:call).and_return(true)
      TelegramSupportBot.configuration.on_user_command = callback

      update = {
        'message' => {
          'message_id' => 2_001,
          'chat' => { 'id' => user_chat_id },
          'text' => '/start lead_123_456'
        }
      }

      expect(callback).not_to receive(:call)
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

    it 'does not treat /starter as /start' do
      update = {
        'message' => {
          'message_id' => 11,
          'chat' => { 'id' => user_chat_id },
          'text' => '/starter'
        }
      }

      expect(adapter).to receive(:forward_message).with(
        from_chat_id: user_chat_id,
        message_id: 11,
        chat_id: support_chat_id
      ).and_return({ 'message_id' => 555 })
      expect(adapter).not_to receive(:send_message).with(chat_id: user_chat_id, text: TelegramSupportBot.configuration.welcome_message)

      TelegramSupportBot.process_update(update)
    end

    it 'does not treat /start123 as /start' do
      update = {
        'message' => {
          'message_id' => 12,
          'chat' => { 'id' => user_chat_id },
          'text' => '/start123'
        }
      }

      expect(adapter).to receive(:forward_message).with(
        from_chat_id: user_chat_id,
        message_id: 12,
        chat_id: support_chat_id
      ).and_return({ 'message_id' => 555 })
      expect(adapter).not_to receive(:send_message).with(chat_id: user_chat_id, text: TelegramSupportBot.configuration.welcome_message)

      TelegramSupportBot.process_update(update)
    end

    it 'passes non-start commands to host callback and does not forward when handled' do
      captured_command = nil
      TelegramSupportBot.configuration.on_user_command = lambda do |**payload|
        captured_command = payload
        true
      end

      update = {
        'message' => {
          'message_id' => 13,
          'chat' => { 'id' => user_chat_id },
          'text' => '/help@my_bot topic one'
        }
      }

      expect(adapter).not_to receive(:forward_message)

      TelegramSupportBot.process_update(update)

      expect(captured_command).to eq(
        command: '/help',
        bot_username: 'my_bot',
        args: 'topic one',
        message: update['message'],
        chat_id: user_chat_id
      )
    end

    it 'forwards non-start commands when host callback does not handle them' do
      TelegramSupportBot.configuration.on_user_command = ->(**_payload) { false }

      update = {
        'message' => {
          'message_id' => 14,
          'chat' => { 'id' => user_chat_id },
          'text' => '/help fallback'
        }
      }

      expect(adapter).to receive(:forward_message).with(
        from_chat_id: user_chat_id,
        message_id: 14,
        chat_id: support_chat_id
      ).and_return({ 'message_id' => 555 })

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

    it 'can forward first /start message to support when configured' do
      TelegramSupportBot.configuration.forward_start_to_support = true

      update = {
        'message' => {
          'message_id' => 15,
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
      expect(adapter).to receive(:forward_message).with(
        from_chat_id: user_chat_id,
        message_id: 15,
        chat_id: support_chat_id
      ).and_return({ 'message_id' => 556 })

      TelegramSupportBot.process_update(update)

      expect(TelegramSupportBot.start_forwarded_users[user_chat_id]).to include(present: true)
      expect(TelegramSupportBot.message_map[556]).to eq(chat_id: user_chat_id, message_id: 15)
    end

    it 'forwards /start only once per user when enabled' do
      TelegramSupportBot.configuration.forward_start_to_support = true
      TelegramSupportBot.configuration.request_contact_on_start = false

      first_start = {
        'message' => {
          'message_id' => 16,
          'chat' => { 'id' => user_chat_id },
          'text' => '/start'
        }
      }
      second_start = {
        'message' => {
          'message_id' => 17,
          'chat' => { 'id' => user_chat_id },
          'text' => '/start'
        }
      }

      expect(adapter).to receive(:forward_message).once.with(
        from_chat_id: user_chat_id,
        message_id: 16,
        chat_id: support_chat_id
      ).and_return({ 'message_id' => 557 })

      TelegramSupportBot.process_update(first_start)
      TelegramSupportBot.process_update(second_start)
    end

    it 'ignores duplicated update_id for /start' do
      TelegramSupportBot.configuration.forward_start_to_support = true
      TelegramSupportBot.configuration.request_contact_on_start = false

      duplicated_update = {
        'update_id' => 7_070_707,
        'message' => {
          'message_id' => 18,
          'chat' => { 'id' => user_chat_id },
          'text' => '/start'
        }
      }

      expect(adapter).to receive(:send_message).once.with(
        chat_id: user_chat_id,
        text: TelegramSupportBot.configuration.welcome_message
      )
      expect(adapter).to receive(:forward_message).once.with(
        from_chat_id: user_chat_id,
        message_id: 18,
        chat_id: support_chat_id
      ).and_return({ 'message_id' => 558 })

      TelegramSupportBot.process_update(duplicated_update)
      TelegramSupportBot.process_update(duplicated_update)
    end

    it 'does not fail update processing when first /start forwarding raises' do
      TelegramSupportBot.configuration.forward_start_to_support = true
      TelegramSupportBot.configuration.request_contact_on_start = false

      start_update = {
        'message' => {
          'message_id' => 19,
          'chat' => { 'id' => user_chat_id },
          'text' => '/start'
        }
      }
      follow_up_update = {
        'message' => {
          'message_id' => 20,
          'chat' => { 'id' => user_chat_id },
          'text' => 'Need help'
        }
      }

      call_count = 0
      allow(adapter).to receive(:forward_message) do
        call_count += 1
        raise StandardError, 'temporary telegram error' if call_count == 1

        { 'message_id' => 559 }
      end

      allow(TelegramSupportBot).to receive(:warn)

      expect { TelegramSupportBot.process_update(start_update) }.not_to raise_error
      expect { TelegramSupportBot.process_update(follow_up_update) }.not_to raise_error
      expect(call_count).to eq(2)
      expect(TelegramSupportBot).to have_received(:warn).with(a_string_including('Failed to forward initial /start'))
    end
  end
end
