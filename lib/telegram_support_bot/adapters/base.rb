# frozen_string_literal: true

module TelegramSupportBot
  module Adapters
    class Base

      attr_reader :bot

      def initialize(**options)
        @options = options
        setup(options)
      end

      def setup(options)
        # Setup based on options, to be overridden by child classes if necessary
      end

      def send_message(chat_id:, text:)
        # Implementation using the telegram-bot gem
      end

      def send_media(chat_id:, type:, media:, **options)
        method = "send_#{type}"
        args = { chat_id: chat_id, **options }
        args[type] = media

        if respond_to?(method, true)
          send(method, **args)
        else
          raise ArgumentError, "Unsupported media type: #{type}"
        end
      end

      def forward_message(from_chat_id:, chat_id:, message_id:)
        # forward messages to the support chat
      end

      def on_message(&block)
        # Implementation to register a block to be called on new messages
      end
    end
  end
end

