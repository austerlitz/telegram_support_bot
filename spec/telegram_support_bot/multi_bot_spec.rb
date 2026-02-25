# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot do
  class MultiBotTestAdapter
    attr_reader :id, :sent_messages, :forward_messages, :media_messages

    def initialize(id:, forwarded_message_id:)
      @id = id
      @forwarded_message_id = forwarded_message_id
      @sent_messages = []
      @forward_messages = []
      @media_messages = []
    end

    def send_message(**payload)
      @sent_messages << payload
      { 'message_id' => payload[:reply_to_message_id] || 0 }
    end

    def forward_message(**payload)
      @forward_messages << payload
      { 'message_id' => @forwarded_message_id }
    end

    def send_media(**payload)
      @media_messages << payload
      { 'message_id' => 9_999 }
    end

    def set_message_reaction(**_payload)
      true
    end
  end

  let(:bot_a_support_chat_id) { -10_001 }
  let(:bot_b_support_chat_id) { -20_002 }

  before do
    configure_bot(
      :bot_a,
      support_chat_id: bot_a_support_chat_id,
      adapter_id: 'bot_a',
      forwarded_message_id: 5_001,
      non_command_ack: 'Ack from bot A'
    )

    configure_bot(
      :bot_b,
      support_chat_id: bot_b_support_chat_id,
      adapter_id: 'bot_b',
      forwarded_message_id: 6_001,
      non_command_ack: 'Ack from bot B'
    )
  end

  it 'keeps message mappings isolated across bots' do
    user_update_for_a = {
      'message' => {
        'message_id' => 101,
        'chat' => { 'id' => 301 },
        'text' => 'Need help from A'
      }
    }

    TelegramSupportBot.process_update(user_update_for_a, bot: :bot_a)

    expect(TelegramSupportBot.message_map(:bot_a)[5_001]).to eq(chat_id: 301, message_id: 101)
    expect(TelegramSupportBot.message_map(:bot_b)[5_001]).to be_nil

    support_reply_for_b = {
      'message' => {
        'message_id' => 401,
        'chat' => { 'id' => bot_b_support_chat_id },
        'reply_to_message' => { 'message_id' => 5_001 },
        'text' => 'Reply from B support'
      }
    }

    TelegramSupportBot.process_update(support_reply_for_b, bot: :bot_b)

    expect(TelegramSupportBot.adapter(:bot_b).media_messages).to eq([])
  end

  it 'routes support chat messages by bot key configuration' do
    update = {
      'message' => {
        'message_id' => 501,
        'chat' => { 'id' => bot_b_support_chat_id },
        'text' => 'operator note'
      }
    }

    TelegramSupportBot.process_update(update, bot: :bot_b)
    TelegramSupportBot.process_update(update, bot: :bot_a)

    expect(TelegramSupportBot.adapter(:bot_b).sent_messages).to include(
      hash_including(
        chat_id: bot_b_support_chat_id,
        text: 'Ack from bot B',
        reply_to_message_id: 501
      )
    )

    expect(TelegramSupportBot.adapter(:bot_a).forward_messages).to include(
      hash_including(
        from_chat_id: bot_b_support_chat_id,
        chat_id: bot_a_support_chat_id,
        message_id: 501
      )
    )
  end

  it 'keeps contact profiles isolated per bot key' do
    contact_from_same_chat = {
      'message' => {
        'message_id' => 701,
        'chat' => { 'id' => 777 },
        'from' => { 'id' => 777, 'username' => 'test_user' },
        'contact' => {
          'user_id' => 777,
          'phone_number' => '+1111111111',
          'first_name' => 'A'
        }
      }
    }

    TelegramSupportBot.process_update(contact_from_same_chat, bot: :bot_a)

    expect(TelegramSupportBot.user_profile(777, bot: :bot_a)).to include(phone_number: '+1111111111')
    expect(TelegramSupportBot.user_profile(777, bot: :bot_b)).to be_nil

    contact_for_bot_b = Marshal.load(Marshal.dump(contact_from_same_chat))
    contact_for_bot_b['message']['message_id'] = 702
    contact_for_bot_b['message']['contact']['phone_number'] = '+2222222222'

    TelegramSupportBot.process_update(contact_for_bot_b, bot: :bot_b)

    expect(TelegramSupportBot.user_profile(777, bot: :bot_a)).to include(phone_number: '+1111111111')
    expect(TelegramSupportBot.user_profile(777, bot: :bot_b)).to include(phone_number: '+2222222222')
  end

  def configure_bot(bot_key, support_chat_id:, adapter_id:, forwarded_message_id:, non_command_ack:)
    TelegramSupportBot.configure(bot_key) do |config|
      config.adapter = MultiBotTestAdapter
      config.adapter_options = {
        id: adapter_id,
        forwarded_message_id: forwarded_message_id
      }
      config.support_chat_id = support_chat_id
      config.ignore_non_command_messages = false
      config.non_command_message_response = non_command_ack
      config.contact_received_message = 'Contact saved'
    end
  end
end
