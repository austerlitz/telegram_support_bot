# frozen_string_literal: true

require 'telegram/bot'
module TelegramSupportBot
  module Adapters
    class TelegramBotRuby < Base

      def initialize(**options)
        super
        @bot = Telegram::Bot::Client.new(@options[:token])
      end

      def send_message(chat_id:, text:, **options)
        bot.api.send_message(chat_id: chat_id, text: text, **options)
      end

      alias_method :send_text, :send_message

      def send_photo(chat_id:, photo:, **options)
        bot.api.send_photo(chat_id: chat_id, photo: photo, **options)
      end

      def send_video(chat_id:, video:, **options)
        bot.api.send_video(chat_id: chat_id, video: video, **options)
      end

      def send_document(chat_id:, document:, **options)
        bot.api.send_document(chat_id: chat_id, document: document, **options)
      end

      def send_audio(chat_id:, audio:, **options)
        bot.api.send_audio(chat_id: chat_id, audio: audio, **options)
      end

      def send_voice(chat_id:, voice:, **options)
        bot.api.send_voice(chat_id: chat_id, voice: voice, **options)
      end

      def send_sticker(chat_id:, sticker:, **options)
        bot.api.send_sticker(chat_id: chat_id, sticker: sticker, **options)
      end

      def forward_message(from_chat_id:, chat_id:, message_id:)
        bot.api.forward_message(chat_id: chat_id, from_chat_id: from_chat_id, message_id: message_id)
      end
    end
  end
end
