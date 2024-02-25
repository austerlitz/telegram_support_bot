# frozen_string_literal: true

module TelegramSupportBot
  module Adapters
    class TelegramBotAdapter < BaseAdapter

      def initialize(**options)
        super
        @bot = Telegram::Bot::Client.new(@options[:token], @options[:username])
      end

      def send_message(chat_id:, text:, **options)
        @bot.send_message(chat_id: chat_id, text: text, **options)
      end

      def send_photo(chat_id:, photo:, **options)
        @bot.send_photo(chat_id: chat_id, photo: photo, **options)
      end

      def send_video(chat_id:, video:, **options)
        @bot.send_video(chat_id: chat_id, video: video, **options)
      end

      def send_document(chat_id:, document:, **options)
        @bot.send_document(chat_id: chat_id, document: document, **options)
      end

      # Handles sending audio messages
      def send_audio(chat_id:, audio:, **options)
        @bot.send_audio(chat_id: chat_id, audio: audio, **options)
      end

      # Handles sending sticker messages
      def send_sticker(chat_id:, sticker:, **options)
        @bot.send_sticker(chat_id: chat_id, sticker: sticker, **options)
      end

      # New generic send_media method
      def send_media(chat_id:, type:, media:, **options)
        case type.to_sym
        when :text
          send_message(chat_id: chat_id, text: media, **options)
        when :photo
          send_photo(chat_id: chat_id, photo: media, **options)
        when :video
          send_video(chat_id: chat_id, video: media, **options)
        when :document
          send_document(chat_id: chat_id, document: media, **options)
        when :audio
          send_audio(chat_id: chat_id, audio: media, **options)
        when :sticker
          send_sticker(chat_id: chat_id, sticker: media, **options)
        else
          raise ArgumentError, "Unsupported media type: #{type}"
        end
      end

      def forward_message(from_chat_id:, chat_id:, message_id:)
        @bot.forward_message(
          chat_id:      chat_id,
          from_chat_id: from_chat_id,
          message_id:   message_id
        )
      end
    end
  end
end
