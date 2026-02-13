# frozen_string_literal: true
require 'spec_helper'

RSpec.describe TelegramSupportBot do
  let(:support_chat_id) { 123456 }
  let(:user_chat_id) { 789012 }
  let(:user_message_id) { 111 }
  let(:support_message_id) { 222 }
  let(:adapter) { instance_double(TelegramSupportBot::Adapters::TelegramBot) }

  before do
    TelegramSupportBot.reset_state_store!
    TelegramSupportBot.configure do |config|
      config.support_chat_id = support_chat_id
      config.adapter = :telegram_bot
    end
    allow(TelegramSupportBot).to receive(:adapter).and_return(adapter)
    # Clear mappings before each test
    TelegramSupportBot.message_map.clear
    TelegramSupportBot.reverse_message_map.clear
    TelegramSupportBot.reaction_count_state.clear
    TelegramSupportBot.user_profiles.clear
  end

  describe '.process_update with message_reaction' do
    context 'when reaction is in support chat' do
      let(:update) do
        {
          'message_reaction' => {
            'chat' => { 'id' => support_chat_id },
            'message_id' => support_message_id,
            'new_reaction' => [{ 'type' => 'emoji', 'emoji' => '👍' }]
          }
        }
      end

      it 'forwards the reaction to the user chat if mapping exists' do
        TelegramSupportBot.message_map[support_message_id] = { chat_id: user_chat_id, message_id: user_message_id }

        expect(adapter).to receive(:set_message_reaction).with(
          chat_id: user_chat_id,
          message_id: user_message_id,
          reaction: [{ 'type' => 'emoji', 'emoji' => '👍' }]
        )

        TelegramSupportBot.process_update(update)
      end

      it 'does nothing if mapping does not exist' do
        expect(adapter).not_to receive(:set_message_reaction)
        TelegramSupportBot.process_update(update)
      end
    end

    context 'when reaction is in user chat' do
      let(:update) do
        {
          'message_reaction' => {
            'chat' => { 'id' => user_chat_id },
            'message_id' => user_message_id,
            'new_reaction' => [{ 'type' => 'emoji', 'emoji' => '❤️' }]
          }
        }
      end

      it 'forwards the reaction to the support chat if reverse mapping exists' do
        TelegramSupportBot.reverse_message_map["#{user_chat_id}:#{user_message_id}"] = support_message_id

        expect(adapter).to receive(:set_message_reaction).with(
          chat_id: support_chat_id,
          message_id: support_message_id,
          reaction: [{ 'type' => 'emoji', 'emoji' => '❤️' }]
        )

        TelegramSupportBot.process_update(update)
      end

      it 'does nothing if reverse mapping does not exist' do
        expect(adapter).not_to receive(:set_message_reaction)
        TelegramSupportBot.process_update(update)
      end

      it 'retries with a single reaction if target chat rejects multiple reactions' do
        multi_reaction = [
          { 'type' => 'emoji', 'emoji' => '❤️' },
          { 'type' => 'emoji', 'emoji' => '🔥' }
        ]
        update['message_reaction']['new_reaction'] = multi_reaction
        TelegramSupportBot.reverse_message_map["#{user_chat_id}:#{user_message_id}"] = support_message_id

        expect(adapter).to receive(:set_message_reaction).ordered.with(
          chat_id: support_chat_id,
          message_id: support_message_id,
          reaction: multi_reaction
        ).and_raise(StandardError.new('Bad Request: REACTIONS_TOO_MANY'))

        expect(adapter).to receive(:set_message_reaction).ordered.with(
          chat_id: support_chat_id,
          message_id: support_message_id,
          reaction: [multi_reaction.first]
        )

        expect { TelegramSupportBot.process_update(update) }.not_to raise_error
      end
    end
  end

  describe '.process_update with message_reaction_count' do
    let(:count_update) do
      {
        'message_reaction_count' => {
          'chat' => { 'id' => support_chat_id },
          'message_id' => support_message_id,
          'reactions' => [
            {
              'type' => { 'type' => 'emoji', 'emoji' => '👍' },
              'total_count' => 1
            }
          ]
        }
      }
    end

    it 'forwards inferred support reaction to user when mapping exists' do
      TelegramSupportBot.message_map[support_message_id] = { chat_id: user_chat_id, message_id: user_message_id }

      expect(adapter).to receive(:set_message_reaction).with(
        chat_id: user_chat_id,
        message_id: user_message_id,
        reaction: [{ 'type' => 'emoji', 'emoji' => '👍' }]
      )

      TelegramSupportBot.process_update(count_update)
    end

    it 'does nothing when mapping does not exist' do
      expect(adapter).not_to receive(:set_message_reaction)
      TelegramSupportBot.process_update(count_update)
    end

    it 'clears mirrored reaction when support count drops to zero' do
      TelegramSupportBot.message_map[support_message_id] = { chat_id: user_chat_id, message_id: user_message_id }

      empty_count_update = {
        'message_reaction_count' => {
          'chat' => { 'id' => support_chat_id },
          'message_id' => support_message_id,
          'reactions' => []
        }
      }

      expect(adapter).to receive(:set_message_reaction).with(
        chat_id: user_chat_id,
        message_id: user_message_id,
        reaction: [{ 'type' => 'emoji', 'emoji' => '👍' }]
      ).ordered

      expect(adapter).to receive(:set_message_reaction).with(
        chat_id: user_chat_id,
        message_id: user_message_id,
        reaction: []
      ).ordered

      TelegramSupportBot.process_update(count_update)
      TelegramSupportBot.process_update(empty_count_update)
    end
  end

  describe 'mapping creation' do
    it 'creates mappings when forwarding message to support chat' do
      user_message = {
        'message_id' => user_message_id,
        'chat' => { 'id' => user_chat_id },
        'text' => 'Hello'
      }
      
      allow(adapter).to receive(:forward_message).and_return({ 'message_id' => support_message_id })

      TelegramSupportBot.send(:forward_message_to_support_chat, user_message, chat_id: user_chat_id)

      expect(TelegramSupportBot.message_map[support_message_id]).to eq({ chat_id: user_chat_id, message_id: user_message_id })
      expect(TelegramSupportBot.reverse_message_map["#{user_chat_id}:#{user_message_id}"]).to eq(support_message_id)
    end

    it 'creates mappings when forwarding message to support chat with wrapped API response' do
      user_message = {
        'message_id' => user_message_id,
        'chat' => { 'id' => user_chat_id },
        'text' => 'Hello'
      }

      allow(adapter).to receive(:forward_message).and_return({ 'ok' => true, 'result' => { 'message_id' => support_message_id } })

      TelegramSupportBot.send(:forward_message_to_support_chat, user_message, chat_id: user_chat_id)

      expect(TelegramSupportBot.message_map[support_message_id]).to eq({ chat_id: user_chat_id, message_id: user_message_id })
      expect(TelegramSupportBot.reverse_message_map["#{user_chat_id}:#{user_message_id}"]).to eq(support_message_id)
    end

    it 'creates mappings when replying in support chat' do
      forwarded_support_message_id = 9001
      TelegramSupportBot.message_map[forwarded_support_message_id] = { chat_id: user_chat_id, message_id: user_message_id }

      admin_reply = {
        'message_id' => support_message_id,
        'chat' => { 'id' => support_chat_id },
        'reply_to_message' => {
          'message_id' => forwarded_support_message_id
        },
        'text' => 'Hi there'
      }

      allow(adapter).to receive(:send_media).and_return({ 'message_id' => 333 })

      TelegramSupportBot.send(:process_reply_in_support_chat, admin_reply)

      expect(TelegramSupportBot.message_map[support_message_id]).to eq({ chat_id: user_chat_id, message_id: 333 })
      expect(TelegramSupportBot.reverse_message_map["#{user_chat_id}:333"]).to eq(support_message_id)
    end

    it 'creates mappings when replying in support chat with wrapped API response' do
      forwarded_support_message_id = 9002
      TelegramSupportBot.message_map[forwarded_support_message_id] = { chat_id: user_chat_id, message_id: user_message_id }

      admin_reply = {
        'message_id' => support_message_id,
        'chat' => { 'id' => support_chat_id },
        'reply_to_message' => {
          'message_id' => forwarded_support_message_id
        },
        'text' => 'Hi there'
      }

      allow(adapter).to receive(:send_media).and_return({ 'ok' => true, 'result' => { 'message_id' => 333 } })

      TelegramSupportBot.send(:process_reply_in_support_chat, admin_reply)

      expect(TelegramSupportBot.message_map[support_message_id]).to eq({ chat_id: user_chat_id, message_id: 333 })
      expect(TelegramSupportBot.reverse_message_map["#{user_chat_id}:333"]).to eq(support_message_id)
    end

    it 'falls back to forward_from when mapping is unavailable' do
      admin_reply = {
        'message_id' => support_message_id,
        'chat' => { 'id' => support_chat_id },
        'reply_to_message' => {
          'message_id' => 9999,
          'forward_from' => { 'id' => user_chat_id }
        },
        'text' => 'Hi there'
      }

      allow(adapter).to receive(:send_media).and_return({ 'message_id' => 333 })

      TelegramSupportBot.send(:process_reply_in_support_chat, admin_reply)

      expect(TelegramSupportBot.message_map[support_message_id]).to eq({ chat_id: user_chat_id, message_id: 333 })
      expect(TelegramSupportBot.reverse_message_map["#{user_chat_id}:333"]).to eq(support_message_id)
    end
  end
end
