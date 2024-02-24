# frozen_string_literal: true

module TelegramSupportBot
  module Adapters
    class TelegramBotAdapter < BaseAdapter

      def initialize(**options)
        super
        @client = Telegram::Bot::Client.new(@options[:token], @options[:username])
      end

      def send_message(chat_id:, text:, **options)
        @client.send_message(chat_id: chat_id, text: text, **options)
      end

      def send_photo(chat_id:, photo:, caption:)
        @client.send_photo(chat_id: chat_id, photo: photo, caption: caption)
      end

      def send_video(chat_id:, video:, caption:)
        @client.send_video(chat_id: chat_id, video: video, caption: caption)
      end

      def send_document(chat_id:, document:, caption:)
        @client.send_document(chat_id: chat_id, document: document, caption: caption)
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
