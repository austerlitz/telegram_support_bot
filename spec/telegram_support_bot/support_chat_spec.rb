# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramSupportBot do
  let(:support_chat_id) { 123_456 }
  let(:adapter) { instance_double(TelegramSupportBot::Adapters::TelegramBot) }

  before do
    TelegramSupportBot.reset_state_store!
    TelegramSupportBot.configure do |config|
      config.support_chat_id = support_chat_id
      config.adapter = :telegram_bot
      config.ignore_non_command_messages = true
      config.non_command_message_response = 'Custom non-command acknowledgement'
    end

    allow(TelegramSupportBot).to receive(:adapter).and_return(adapter)
    allow(adapter).to receive(:send_message)
  end

  describe 'support chat non-command behavior' do
    let(:non_command_update) do
      {
        'message' => {
          'message_id' => 101,
          'chat' => { 'id' => support_chat_id },
          'text' => 'internal note'
        }
      }
    end

    it 'ignores non-command messages by default' do
      expect(adapter).not_to receive(:send_message)
      TelegramSupportBot.process_update(non_command_update)
    end

    it 'can acknowledge non-command messages when configured' do
      TelegramSupportBot.configuration.ignore_non_command_messages = false

      expect(adapter).to receive(:send_message).with(
        chat_id: support_chat_id,
        text: 'Custom non-command acknowledgement',
        reply_to_message_id: 101
      )

      TelegramSupportBot.process_update(non_command_update)
    end
  end
end
