# frozen_string_literal: true

module TelegramSupportBot
  module Adapters
    class TelegramBotAdapter < BaseAdapter

      def initialize(**options)
        super
        @client = Telegram::Bot::Client.new(@options[:token], @options[:username])
      end

      def send_message(chat_id:, text:)
        @client.send_message(chat_id: chat_id, text: text)
      end

      def forward_message(from_chat_id:, chat_id:, message_id:)
        @client.forward_message(
          chat_id: chat_id,
          from_chat_id: from_chat_id,
          message_id: message_id
        )
      end
    end
  end
end
