# frozen_string_literal: true

module TelegramSupportBot
  module Adapters
    class BaseAdapter
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

      def forward_message(from_chat_id:, chat_id:, message_id:)
        # Implementation using the telegram-bot gem
      end

      def on_message(&block)
        # Implementation to register a block to be called on new messages
      end
    end
  end
end

